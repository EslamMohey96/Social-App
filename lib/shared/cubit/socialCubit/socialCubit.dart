import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:social_app/models/massageModel.dart';
import 'package:social_app/models/postModel.dart';
import 'package:social_app/models/userModel.dart';
import 'package:social_app/modules/socialLayout/navBar/chatsScreen/chats.dart';
import 'package:social_app/modules/socialLayout/navBar/feedsScreen/feeds.dart';
import 'package:social_app/modules/socialLayout/menu/settingsScreen/seetings.dart';
import 'package:social_app/modules/socialLayout/navBar/usersScreen/users.dart';
import 'package:social_app/shared/components/constants.dart';
import 'package:social_app/shared/cubit/socialCubit/socialStates.dart';

class socialCubit extends Cubit<socialStates> {
  socialCubit() : super(socialInitState());
  static socialCubit get(context) => BlocProvider.of(context);

  GlobalKey<FormState> formKey = GlobalKey();
  GlobalKey<FormState> formKeyPost = GlobalKey();
  GlobalKey<FormState> formKeyMassage = GlobalKey();

  late TextEditingController nameController;
  late TextEditingController bioController;
  late TextEditingController phoneController;
  late TextEditingController emailController = TextEditingController();
  late TextEditingController postController = TextEditingController();
  late TextEditingController chatController = TextEditingController();

  ImagePicker imagePicker = ImagePicker();
  final storage = FirebaseStorage.instance;

//profileImage
  XFile? profileImage;
  Future<void> getImage() async {
    try {
      profileImage = await imagePicker.pickImage(source: ImageSource.gallery);
      uploadImage();
      emit(profileImageSuccessState());
    } on FirebaseAuthException catch (e) {
      emit(profileImageErrorState(e.message));
    }
  }

  String fileProfileImage = '';
  void uploadImage() {
    File file = File(profileImage!.path);
    try {
      storage
          .ref()
          .child('users/${Uri.file(file.path).pathSegments.last}')
          .putFile(file)
          .then((value) {
        value.ref.getDownloadURL().then((value) {
          fileProfileImage = value;
        });
      });
    } on FirebaseAuthException catch (e) {
      emit(profileImageErrorState(e.message));
    }
  }

// coverImage
  XFile? coverImage;
  Future<void> getCover() async {
    try {
      coverImage = await imagePicker.pickImage(source: ImageSource.gallery);
      uploadCover();
      emit(coverImageSuccessState());
    } on FirebaseAuthException catch (e) {
      emit(coverImageErrorState(e.message));
    }
  }

  String fileCoverImage = '';
  void uploadCover() {
    try {
      File file = File(coverImage!.path);
      storage
          .ref()
          .child('users/${Uri.file(file.path).pathSegments.last}')
          .putFile(file)
          .then((value) {
        value.ref.getDownloadURL().then((value) {
          fileCoverImage = value;
        });
      });
    } on FirebaseAuthException catch (e) {
      emit(coverImageErrorState(e.message));
    }
  }

// postImage
  XFile? postImage;
  Future<void> getPostImage() async {
    try {
      filePostImage = '';
      emit(getPostImageLoading());
      await imagePicker.pickImage(source: ImageSource.gallery).then((value) {
        postImage = value;
        uploadPostImage();
      });
    } on FirebaseAuthException catch (e) {
      emit(postImageErrorState(e.message));
    }
  }

  int postImageDone = 0;
  String filePostImage = '';
  void uploadPostImage() {
    try {
      postImageDone = 2;
      File file = File(postImage!.path);
      storage
          .ref()
          .child('posts/${Uri.file(file.path).pathSegments.last}')
          .putFile(file)
          .then((value) {
        value.ref.getDownloadURL().then((value) {
          filePostImage = value;
          postImageDone = 1;
        }).then((value) => emit(postImageSuccessState()));
      });
    } on FirebaseAuthException catch (e) {
      emit(postImageErrorState(e.message));
    }
  }

// createPost
  void createPost() async {
    try {
      postModel post = postModel(
        uId: uIdConst,
        name: user_model!.name,
        image: user_model!.image,
        postText: postController.text,
        postImage: filePostImage,
        date: DateFormat('yyyy-MM-dd hh:mm').format(DateTime.now()).toString(),
      );
      await FirebaseFirestore.instance
          .collection('myPosts')
          .doc()
          .set(post.toMap());
      // .then((value) => getMyPosts(uIdConst)
      // );
    } on FirebaseAuthException catch (e) {
      emit(createPostErrorState(e.message));
    }
  }

// getPosts
  late List<postModel> myPosts = [];
  late List<postModel> Posts = [];
  int myPosts_Done = 0;
  String welcomeImage = '';
  void getMyPosts() async {
    try {
      myPosts_Done = 0;
      emit(myPostsLoadingState());
      await FirebaseFirestore.instance
          .collection('myPosts')
          .orderBy('date')
          .snapshots()
          .listen((event) {
        myPosts = [];
        event.docs.forEach((element) {
          myPosts.add(postModel.fromJson(element.data()));
        });
        postController.text = '';
        emit(myPostsSuccessState());
      });
    } on FirebaseAuthException catch (e) {
      emit(myPostsErrorState(e.message));
    }
  }

// updateUserData
  int updateUserDataCounter = 1;
  void updateUserData() async {
    try {
      user_model_Done = 0;
      emit(updateUserDataLoadingState());
      await FirebaseFirestore.instance.collection('users').doc(uIdConst).set({
        "name": nameController.text,
        "bio": bioController.text,
        "email": user_model!.email,
        "phone": phoneController.text,
        "isEmailVerified": false,
        "uId": user_model!.uId,
        "background":
            fileCoverImage == '' ? user_model!.background : fileCoverImage,
        "image": fileProfileImage == '' ? user_model!.image : fileProfileImage,
      }).then((value) {
        emit(updateUserDataSuccessState());
        getUserData(uIdConst);
      });
    } on FirebaseAuthException catch (e) {
      emit(updateUserDataErrorState(e.message));
    }
  }

// getUserData
  userModel? user_model;
  int user_model_Done = 0;
  void getUserData(String uId) async {
    try {
      user_model_Done = 0;
      emit(userDataLoadingState());
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uId)
          .get()
          .then((value) {
        user_model = userModel.fromJson(value.data());
      }).then((value) {
        fileProfileImage = user_model!.image;
        fileCoverImage = user_model!.background;
        nameController = TextEditingController(text: user_model!.name);
        bioController = TextEditingController(text: user_model!.bio);
        phoneController = TextEditingController(text: user_model!.phone);
        user_model_Done = 1;
        emit(userDataSuccessState());
      });
    } on FirebaseAuthException catch (e) {
      emit(userDataErrorState(e.message));
    }
  }

// getUsers
  List<userModel>? users = [];
  int users_list_Done = 0;
  void getUsers() async {
    try {
      users = [];
      emit(usersLoadingState());
      await FirebaseFirestore.instance
          .collection('users')
          .snapshots()
          .listen((event) {
        users = [];
        event.docs.forEach((element) {
          if (element.id != uIdConst)
            users!.add(userModel.fromJson(element.data()));
          print('${users.toString()}+++');
          users_list_Done = 1;
          emit(usersSuccessState());
        });
      });
    } on FirebaseAuthException catch (e) {
      emit(usersErrorState(e.message));
    }
  }

// sendMassage
  void sendMassage({
    required String receiver,
    required String text,
  }) async {
    try {
      // String date =
      //     DateFormat('yyyy-MM-dd hh:mm:ss').format(DateTime.now()).toString();
      chatController.text = '';
      // print(date);
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user_model!.uId)
          .collection('chats')
          .doc(receiver)
          .collection('massages')
          .add({
        'date':
            DateFormat('yyyy-MM-dd hh:mm:ss').format(DateTime.now()).toString(),
        'sender': user_model!.uId,
        'receiver': receiver,
        'text': text,
      }).then((value) {
        print('${value}----------');
        print('----------');
        FirebaseFirestore.instance
            .collection('users')
            .doc(receiver)
            .collection('chats')
            .doc(user_model!.uId)
            .collection('massages')
            .add({
          'date': DateFormat('yyyy-MM-dd hh:mm:ss')
              .format(DateTime.now())
              .toString(),
          'sender': user_model!.uId,
          'receiver': receiver,
          'text': text,
        }).then((value) {
          emit(sendMassageSuccessState());
        });
      });
    } on FirebaseAuthException catch (e) {
      emit(sendMassageErrorState(e.message));
    }
  }

// getMassages
  List<massageModel> massages_list = [];
  void getMassage({
    required String receiver,
  }) {
    try {
      FirebaseFirestore.instance
          .collection('users')
          .doc(user_model!.uId)
          .collection('chats')
          .doc(receiver)
          .collection("massages")
          .orderBy("date")
          .snapshots()
          .listen((event) {
        massages_list = [];
        event.docs.forEach((element) {
          massages_list.add(massageModel.fromJson(element.data()));
          emit(getMassageSuccessState());
        });
      });
    } on FirebaseAuthException catch (e) {
      emit(getMassageErrorState(e.message));
    }
  }

// changeNavState
  int currentIndex = 0;
  List<Widget> screens = [
    feeds(),
    chats(),
    usersScreen(),
    settings(),
  ];
  List<String> titles = [
    "Feeds",
    "Chats",
    "Users",
    "Settings",
  ];
  void changeCurrentIndex(index) {
    currentIndex = index;
    emit(changeNavState());
  }
}

// class getImageByImagePicker extends Cubit<socialStates> {
//   getImageByImagePicker() : super(getPostImageLoading());
//    static getImageByImagePicker get(context) => BlocProvider.of(context);
//   ImagePicker imagePicker = ImagePicker();
//   XFile? image;
//   Future<XFile?> getImage() async {
//     try {
//       image = await imagePicker.pickImage(source: ImageSource.gallery);
//       emit(profileImageSuccessState());
//       return image;
//     } on FirebaseAuthException catch (e) {
//       emit(profileImageErrorState(e.message));
//     }
//     return null;
//   }
// }

// class uploadImage extends Cubit<socialStates> {
//   uploadImage() : super(getPostImageLoading());
//   final storage = FirebaseStorage.instance;

//   String fileProfileImage = '';
//   String upload(Future<XFile?> profileImage) {
//     try {
//       File file = File(profileImage.then((value) => value!.path).toString());
//       storage
//           .ref()
//           .child('users/${Uri.file(file.path).pathSegments.last}')
//           .putFile(file)
//           .then((value) {
//         value.ref.getDownloadURL().then((value) {
//           fileProfileImage = value;
//           return fileProfileImage;
//         });
//       });
//       return fileProfileImage;
//     } on FirebaseAuthException catch (e) {
//       emit(profileImageErrorState(e.message));
//     }
//     return '';
//   }
// }
