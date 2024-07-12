import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as Path;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Chatbox',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  TextEditingController _messageController = TextEditingController();
  File? _imageFile;
  final picker = ImagePicker();
  bool _isLoading = false;
  String userId = 'user_id';

  @override
  void initState() {
    super.initState();
    // Add initial message when the screen is initialized
    _addInitialMessage();
  }

  Future<void> _addInitialMessage() async {
    String initialMessage = "Hello, how can I be helpful today?!";
    try {
      await FirebaseFirestore.instance.collection('messages').add({
        'id': 'ai_id',
        'prompt': initialMessage,
        'time': Timestamp.now(),
      });
    } catch (e) {
      print("Error adding initial message: $e");
    }
  }

  Future<void> _sendMessage() async {
    String message = _messageController.text;
    String? imageUrl;

    if (_imageFile != null) {
      setState(() {
        _isLoading = true;
      });
      imageUrl = await _uploadImage();
    }

    if (message.isNotEmpty || imageUrl != null) {
      await FirebaseFirestore.instance.collection('messages').add({
        'id': userId,
        'text': message,
        'imageUrl': imageUrl,
        'time': Timestamp.now(),
      });

      setState(() {
        _messageController.clear();
        _imageFile = null;
        _isLoading = false;
      });
    }
  }

  Future<String?> _uploadImage() async {
    try {
      String fileName = Path.basename(_imageFile!.path);
      Reference firebaseStorageRef = FirebaseStorage.instance.ref().child('images/$fileName');
      UploadTask uploadTask = firebaseStorageRef.putFile(_imageFile!);
      TaskSnapshot taskSnapshot = await uploadTask;
      return await taskSnapshot.ref.getDownloadURL();
    } catch (e) {
      print(e);
      return null;
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    setState(() {
      if (pickedFile != null) {
        _imageFile = File(pickedFile.path);
      } else {
        print('No image selected.');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Flutter Chatbox'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('messages').orderBy('time', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data!.docs;


                return ListView.builder(
                  reverse: true, // Ensure messages are shown from newest to oldest
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var commentData = messages[index].data() as Map<String, dynamic>;
                    bool isCurrentUser = commentData['id'] == userId;

                    return Align(
                      alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        padding: EdgeInsets.all(12),
                        margin: EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isCurrentUser ? Colors.blue[300] : Colors.grey[200],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (isCurrentUser)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Image.network(
                                    commentData['imageUrl'],
                                    width: 200, // Adjust width as needed
                                    height: 200, // Adjust height as needed
                                    fit: BoxFit.cover, // Adjust the fit as needed
                                  ),
                                  // SizedBox(height: hasImage ? 8 : 0),
                                  Text(
                                    commentData['text'],
                                    style: TextStyle(
                                      color: isCurrentUser ? Colors.white : Colors.black,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              )
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    commentData['prompt'],
                                    style: TextStyle(
                                      color: Colors.black, // Adjust color as needed
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            SizedBox(height: 4),
                            Text(
                              DateFormat('hh:mm a, MMM d, yyyy').format(
                                (commentData['time'] as Timestamp).toDate(),
                              ),
                              style: TextStyle(
                                color: isCurrentUser ? Colors.white70 : Colors.grey,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_imageFile != null)
            Image.file(
              _imageFile!,
              height: 150,
            ),
          _isLoading ? CircularProgressIndicator() : SizedBox.shrink(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                IconButton(
                  icon: Icon(Icons.photo),
                  onPressed: _pickImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(hintText: 'Enter your message'),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
