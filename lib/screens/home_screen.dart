import 'package:blocauth/cubits/auth_cubit/auth_cubit.dart';
import 'package:blocauth/cubits/auth_cubit/auth_state.dart';
import 'package:blocauth/screens/sign_in_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

User? user = auth.currentUser;
FirebaseAuth auth = FirebaseAuth.instance;

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String location = 'Searching';

  String Address = 'Finding';

  Future<Position> _getGeoLocationPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> GetAddressFromLatLong(Position position) async {
    List<Placemark> placemarks =
        await placemarkFromCoordinates(position.latitude, position.longitude);
    print(placemarks);
    Placemark place = placemarks[0];
    Address =
        '${place.street}, ${place.subLocality}, ${place.locality},${place.thoroughfare},${place.administrativeArea} ${place.postalCode}, ${place.country}';
    setState(() {});
  }

  Future<void> get() async {
    Position position = await _getGeoLocationPosition();
    location = 'Lat: ${position.latitude} , Long: ${position.longitude}';
    GetAddressFromLatLong(position);
  }

  @override
  void initState() {
    super.initState();
    get();
  }

  Stream<List<DocumentSnapshot>> getAllDocuments() {
    return FirebaseFirestore.instance
        .collection('location')
        .doc(user?.phoneNumber)
        .collection(user!.phoneNumber.toString())
        .snapshots()
        .map(
          (QuerySnapshot querySnapshot) => querySnapshot.docs,
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Text("Home"),
      ),
      body: SafeArea(
        child: Container(
          child: Column(
            children: [
              Text(location),
              Text(Address),
              ElevatedButton(
                  onPressed: () {
                    get();

                    FirebaseFirestore.instance
                        .collection('location')
                        .doc(user?.phoneNumber)
                        .collection(user!.phoneNumber.toString())
                        .add({
                      'longitude': location.toString(),
                      'Address': Address.toString(),
                      'user': user?.uid,
                      'phone': user?.phoneNumber
                    });
                  },
                  child: Text('Get Location')),

              Container(
                child: Expanded(
                  child: StreamBuilder<List<DocumentSnapshot>>(
                    stream: getAllDocuments(),
                    builder: (BuildContext context,
                        AsyncSnapshot<List<DocumentSnapshot>> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return CircularProgressIndicator();
                      }
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      }
                      List<DocumentSnapshot> documents = snapshot.data!;
                      return ListView.builder(
                        itemCount: documents.length,
                        itemBuilder: (BuildContext context, int index) {
                          DocumentSnapshot ds = documents[index];
                          return Dismissible(
                              key: Key(documents[index].id),
                              background: Container(color: Colors.red),
                              onDismissed: (direction) {
                                // Delete the data from Firestore
                                FirebaseFirestore.instance
                                    .collection("location")
                                    .doc(user?.phoneNumber)
                                    .collection(user!.phoneNumber.toString())
                                    .doc(documents[index].id)
                                    .delete();
                              },
                              child: ListTile(
                                title: Text(documents[index]['longitude']),
                                subtitle: Text(documents[index]['Address']),
                                trailing: IconButton(
                                  onPressed: () async {
                                    FirebaseFirestore.instance
                                        .collection("location")
                                        .doc(user?.phoneNumber)
                                        .collection(
                                            user!.phoneNumber.toString())
                                        .doc(documents[index].id)
                                        .delete();
                                  },
                                  icon: Icon(Icons.delete),
                                ),
                              ));
                        },
                      );
                    },
                  ),
                ),
              ),
              Text('Swipe or press delete Icon'),
              Center(
                child: BlocConsumer<AuthCubit, AuthState>(
                  listener: (context, state) {
                    if (state is AuthLoggedOutState) {
                      Navigator.popUntil(context, (route) => route.isFirst);
                      Navigator.pushReplacement(
                          context,
                          CupertinoPageRoute(
                              builder: (context) => SignInScreen()));
                    }
                  },
                  builder: (context, state) {
                    return CupertinoButton(
                      onPressed: () {
                        BlocProvider.of<AuthCubit>(context).logOut();
                      },
                      child: Text("Log out"),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
