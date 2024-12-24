import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Initialize Firestore
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'A&S Event Booking',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,

        scaffoldBackgroundColor: Colors.white,
        textTheme: TextTheme(
          headline6: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold, color: Colors.black),
          bodyText2: TextStyle(fontSize: 16.0, color: Colors.black),
        ),
        buttonTheme: ButtonThemeData(
          buttonColor: Colors.blue,
          textTheme: ButtonTextTheme.primary,
        ),
        ),
      home: WelcomeScreen(),
    );
  }
}

class WelcomeScreen extends StatefulWidget {
  @override
  _WelcomeScreenState createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  File? _image;
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController text1Controller = TextEditingController();
  final TextEditingController text2Controller = TextEditingController();

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );

    setState(() {
      _image = pickedFile != null ? File(pickedFile.path) : null;
    });
  }

  Future<void> _onSearchPressed() async {
    if (_image != null) {
      // Upload the image to Firebase Storage
      String? downloadUrl = await _firebaseService.uploadImage(_image!);
      if (downloadUrl != null) {
        // Save downloadUrl along with text1 and text2 to Firebase Realtime Database or Firestore
        print('Image uploaded. Download URL: $downloadUrl');
        FirebaseService.addData(
          text1Controller.text,
          text2Controller.text,
          downloadUrl,
        );

        // Navigate to FirebaseActivity after saving data
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FirebaseActivity(
              text1: text1Controller.text,
              text2: text2Controller.text,
              downloadUrl: downloadUrl,
            ),
          ),
        );
      } else {
        print('Failed to upload image.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'A&S Event Booking',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.blue,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          // Centered TextInputs and Button
          Center(

            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,

              children: [
                // Image Picker Button
                ElevatedButton(
                  onPressed: _pickImage,
                  child: Text('Pick Image'),
                ),

                // TextInput 1
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: TextField(
                    controller: text1Controller,
                    decoration: InputDecoration(
                      hintText: 'Enter Event',
                      fillColor: Colors.transparent,
                      filled: true,
                    ),
                  ),
                ),
                // TextInput 2
                Padding(
                  padding: EdgeInsets.all(16.0),
                  child: TextField(
                    controller: text2Controller,
                    decoration: InputDecoration(
                      hintText: 'Enter Description',
                      fillColor: Colors.transparent,
                      filled: true,
                    ),
                  ),
                ),
                // Button
                ElevatedButton(
                  onPressed: _onSearchPressed,
                  child: Text('Search'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FirebaseService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<String?> uploadImage(File imageFile) async {
    try {
      String fileName = DateTime.now().millisecondsSinceEpoch.toString();
      Reference reference = _storage.ref().child('images/$fileName');
      UploadTask uploadTask = reference.putFile(imageFile);

      TaskSnapshot taskSnapshot = await uploadTask.whenComplete(() => null);
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      print('Error uploading image: $e');
      return null;
    }
  }

  static Future<void> addData(String text1, String text2, String downloadUrl) async {
    // Implement adding data to Firestore Database
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      CollectionReference events = firestore.collection('events');

      await events.add({
        'text1': text1,
        'text2': text2,
        'downloadUrl': downloadUrl,
      });

      print('Data added to Firestore successfully.');
    } catch (e) {
      print('Error adding data to Firestore: $e');
    }
    // Implement adding data to Firebase Realtime Database
    try {
      DatabaseReference databaseReference = FirebaseDatabase.instance.reference();
      DatabaseReference events = databaseReference.child('events');

      await events.push().set({
        'text1': text1,
        'text2': text2,
        'downloadUrl': downloadUrl,
        // Add more fields if needed
      });

      print('Data added to Realtime Database successfully.');
    } catch (e) {
      print('Error adding data to Realtime Database: $e');
    }

    print('Adding data to Firebase: Text1: $text1, Text2: $text2, Download URL: $downloadUrl');
  }
  static Future<void> deleteData(String text1, String? downloadUrl) async {
    try {
      if(downloadUrl != null){
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      CollectionReference events = firestore.collection('events');

      QuerySnapshot querySnapshot =
      await events.where('text1', isEqualTo: text1).get();

      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        await doc.reference.delete();
      }

      print('Data deleted from Firestore successfully.');
    }else {
    print('Download URL is null. Unable to delete data.');
    }
    } catch (e) {
      print('Error deleting data from Firestore: $e');
    }
  }
  static Future<void> updateData(
      String oldText1,
      String newText1,
      String newText2,
      String? downloadUrl,
      ) async {
    try {
      FirebaseFirestore firestore = FirebaseFirestore.instance;
      CollectionReference events = firestore.collection('events');

      QuerySnapshot querySnapshot =
      await events.where('text1', isEqualTo: oldText1).get();

      for (QueryDocumentSnapshot doc in querySnapshot.docs) {
        await doc.reference.update({
          'text1': newText1,
          'text2': newText2,
        });
      }

      print('Data updated in Firestore successfully.');
    } catch (e) {
      print('Error updating data in Firestore: $e');
    }
  }
}

class FirebaseActivity extends StatelessWidget {
  final String text1;
  final String text2;
  final String? downloadUrl;

  FirebaseActivity({
    required this.text1,
    required this.text2,
    required this.downloadUrl,
  });

  @override
  Widget build(BuildContext context) {
    // Implement the display of data from Firebase in this screen
    // You can use text1, text2, and pickedImage variables here
    return Scaffold(
      appBar: AppBar(
        title: Text('A&S Event List'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [/*
            Text('Text 1: $text1'),
            Text('Text 2: $text2'),
            if (downloadUrl != null)
              Image.network(
                downloadUrl!,
                width: 100,
                height: 100,
              ),*/
             SizedBox(height: 20),
             Text(
             'List of Events:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Expanded(
              child: EventList(),
              ),
          ],
        ),
      ),
    );
  }
}

class EventList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('events').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return CircularProgressIndicator();
        }

        List<DocumentSnapshot> documents = snapshot.data!.docs;

        return ListView.builder(
          itemCount: documents.length,
          itemBuilder: (context, index) {
            String text1 = documents[index]['text1'];
            String text2 = documents[index]['text2'];
            String? downloadUrl = documents[index]['downloadUrl'];
            return GestureDetector(
                onTap: () {
                  // Navigate to EventDetailScreen when a list item is tapped
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EventDetailScreen(
                        text1: text1,
                        text2: text2,
                        downloadUrl: downloadUrl,
                      ),
                    ),
                  );
                },
               child: Column(
                children: [
                    ListTile(
                      title: Text(text1),
              /*subtitle: Text(text2),
              leading: downloadUrl != null
                  ? Image.network(
                downloadUrl,
                width: 50,
                height: 50,
              )
                  : null,*/
            ),
                  Divider(color: Colors.black,),
            ]
               ),
            );
          },
        );
      },
    );
  }
}
class EventDetailScreen extends StatelessWidget {
  final String text1;
  final String text2;
  final String? downloadUrl;

  EventDetailScreen({
    required this.text1,
    required this.text2,
    required this.downloadUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('A&S Event Detail'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Display Image from Firebase in the background (top 50% of the screen)
          Container(
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(downloadUrl ?? ''),
                fit: BoxFit.cover,
              ),
            ),
            child: Center(
              child: Text(
                text1,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Display Title and Description
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Title: $text1',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 10),
                Text(
                  'Description: $text2',
                  style: TextStyle(fontSize: 18),
                ),
              ],
            ),
          ),
          // Buttons for Edit and Delete
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton(
                onPressed: () {
                  // Implement navigation to the edit screen
                  // Pass the necessary data to the edit screen
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditEventScreen(
                        text1: text1,
                        text2: text2,
                        downloadUrl: downloadUrl,
                      ),
                    ),
                  );
                },
                child: Text('Edit'),
              ),
              ElevatedButton(
                onPressed: () {
                  // Implement the delete functionality
                  // Delete the selected event from Firebase
                  FirebaseService.deleteData(text1, downloadUrl);
                  // Navigate back to the previous screen
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(primary: Colors.red),
                child: Text('Delete'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
class EditEventScreen extends StatefulWidget {
  String text1;
  String text2;
  final String? downloadUrl;

  EditEventScreen({
    required this.text1,
    required this.text2,
    required this.downloadUrl,
  });

  @override
  _EditEventScreenState createState() => _EditEventScreenState();
}

class _EditEventScreenState extends State<EditEventScreen> {
  TextEditingController text1Controller = TextEditingController();
  TextEditingController text2Controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    text1Controller.text = widget.text1;
    text2Controller.text = widget.text2;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Event'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Title:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            TextField(controller: text1Controller),
            SizedBox(height: 10),
            Text(
              'Description:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            TextField(controller: text2Controller),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () async {
                // Update the event in Firebase Firestore
                FirebaseService.updateData(
                  widget.text1,
                  text1Controller.text,
                  text2Controller.text,
                  widget.downloadUrl,
                ).then((_) {
                  // Update the local state to reflect the changes immediately
                  setState(() {
                    widget.text1 = text1Controller.text;
                    widget.text2 = text2Controller.text;
                  });
                  // Navigate back to EventDetailScreen with updated data
                  Navigator.pop(context);
                });
              },
              child: Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}

