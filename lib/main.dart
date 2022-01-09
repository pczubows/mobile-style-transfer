import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:gallery_saver/gallery_saver.dart';


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
      initialRoute: '/',
      routes: {
        '/': (context) => Gallery()
      },
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
    RouteSettings? routeSettings = ModalRoute.of(context)?.settings;
    final args = routeSettings?.arguments != null ? routeSettings!.arguments as GalleryArgs : GalleryArgs(false, Future<Null>.value(null) );
    return Scaffold(
      appBar: AppBar(
        title: Text('Pictures'),
      ),
      body: GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
          itemCount: assets.length,
          itemBuilder: (_, index){
            return Thumbnail(asset: assets[index], args: args);
          }
      )
    );
  }
}

class Thumbnail extends StatefulWidget {
  const Thumbnail({Key? key, required this.asset, required this.args}) : super(key: key);

  final AssetEntity asset;
  final GalleryArgs args;

  @override
  _ThumbnailState createState() => _ThumbnailState();
}

class _ThumbnailState extends State<Thumbnail> {
  void transferStyle(Future<File?> inputImageFile) async {
    inputImageFile.then((inputFile) async {
      img.Image inputImage = img.decodeImage(await inputFile!.readAsBytes() )!;

      widget.asset.file.then((styleFile) async {
        final predictionModel = StylePredictionModel();
        final transferModel = StyleTransferModel();

        await predictionModel.loadModel();
        await transferModel.loadModel();

        img.Image styleImage = img.decodeImage(await styleFile!.readAsBytes())!;
        var style = [[[predictionModel.predict(styleImage)]]];

        img.Image? outputImage = transferModel.predict(inputImage, style);
        final filename = '${inputFile.path.split("/").last.split('.').first}_${styleFile.path.split("/").last.split('.').first}.jpeg';
        final Directory appDir = await getApplicationDocumentsDirectory();
        final String path = '${appDir.path}/$filename';
        File file  = await File(path).writeAsBytes(img.encodeJpg(outputImage!));
        GallerySaver.saveImage(file.path);
      });
    });

  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
        future: widget.asset.thumbData,
        builder: (_, snapshot){
          final bytes = snapshot.data;
          if(bytes == null) return CircularProgressIndicator();
          return InkWell(
            onTap: () {
              if(widget.asset.type == AssetType.image){
                if(!widget.args.styleSelected){
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ImageScreen(imageFile: widget.asset.file)));
                }else{
                  transferStyle(widget.args.imageFile);
                  Navigator.pushNamed(context, '/', arguments: null);
                }
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

class GalleryArgs {
  final bool styleSelected;
  final Future<File?> imageFile;

  GalleryArgs(this.styleSelected, this.imageFile);
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
                        onPressed: (){
                          Navigator.pushNamed(context, '/', arguments: GalleryArgs(true, imageFile));
                          },
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
