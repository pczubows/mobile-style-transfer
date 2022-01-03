import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

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
            return Thumbnail(asset: assets[index]);
          }
      )
    );
  }
}

class Thumbnail extends StatelessWidget {
  const Thumbnail({Key? key, required this.asset}) : super(key: key);

  final AssetEntity asset;

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
                Navigator.push(context, MaterialPageRoute(builder: (_) => ImageScreen(imageFile: asset.file)));
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
  const ImageScreen({Key? key, required this.imageFile}) : super(key: key);

  final Future<File?> imageFile;

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
                        onPressed: (){},
                    ),
                ),
                Padding(
                  padding: EdgeInsets.all(10),
                  child: FloatingActionButton(
                    onPressed: (){},
                  ),
                ),
              ],
            )
        )
      ]
    );
  }
}
