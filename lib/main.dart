import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import 'model.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Neural Style Transfer',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Gallery(),
    );
  }
}

class Gallery extends StatefulWidget {
  const Gallery({Key? key}) : super(key: key);

  @override
  _GalleryState createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  var assets = <AssetEntity>[];
  late StyleModel _styleModel;

  //TODO: Rewrite to paginated
  _fetchAssets() async {
    final albums = await PhotoManager.getAssetPathList(onlyAll: true);
    final recentAlbum = albums.first;
    final recentAssets = await recentAlbum.getAssetListRange(start: 0, end: 1000);
    setState(() {
      assets = recentAssets;
    });
  }

  void _checkPermissions() async {
    final permissions = await PhotoManager.requestPermissionExtend();
    if(permissions.isAuth) return;
    else PhotoManager.openSetting();
  }

  @override
  void initState(){
    _fetchAssets();
    _styleModel = StyleModel();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    _checkPermissions();
    return Scaffold(
      appBar: AppBar(
        title: Text('Pictures'),
      ),
      body: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
          itemCount: assets.length,
          itemBuilder: (_, index){
            return Thumbnail(asset: assets[index], styleModel: _styleModel);
          }
      )
    );
  }
}

class Thumbnail extends StatelessWidget {
  const Thumbnail({Key? key, required this.asset, required this.styleModel}) : super(key: key);

  final AssetEntity asset;
  final StyleModel styleModel;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
        future: asset.thumbData,
        builder: (_, snapshot){
          final bytes = snapshot.data;
          if(bytes == null) return CircularProgressIndicator();
          return InkWell(
            onTap: () {
              if(asset.type == AssetType.image){
                Navigator.push(context, MaterialPageRoute(builder: (_) => ImageScreen(imageFile: asset.file, styleModel: styleModel,)));
              }
            },
            child: Stack(
              children: [
                Positioned.fill(child: Image.memory(bytes, fit: BoxFit.cover))
              ],
            ),
          );
        }
    );
  }
}

class ImageScreen extends StatelessWidget {
  const ImageScreen({Key? key, required this.imageFile, required this.styleModel}) : super(key: key);

  final Future<File?> imageFile;
  final StyleModel styleModel;

  void predictStyle() async {
    imageFile.then((value) async {
      final imgBytes = await value!.readAsBytes();
      img.Image inputImage = img.decodeImage(imgBytes)!;
      var style = styleModel.predict(inputImage);
      print(style);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
          children:[
          Container(
            alignment: Alignment.center,
            color: Colors.black,
            child:
              FutureBuilder<File?>(
                future: imageFile,
                builder: (_, snapshot) {
                  final file = snapshot.data;
                  if(file == null) return Container();
                  return Image.file(file);
              }
            )
          ),
          Positioned(
            bottom: 10,
            right: 10,
            child: Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(10),
                  child: FloatingActionButton(
                        onPressed: predictStyle,
                        child: Icon(Icons.brush),
                    ),
                ),
                Padding(
                  padding: EdgeInsets.all(10),
                  child: FloatingActionButton(
                    onPressed: (){},
                    child: Icon(Icons.ios_share),
                  ),
                ),
              ],
            )
        )
      ]
    );
  }
}
