import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(ASLVideoGeneratorApp());
}

class ASLVideoGeneratorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Chihnam',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.grey[200],
      ),
      home: ASLHomePage(),
    );
  }
}

class ASLHomePage extends StatefulWidget {
  @override
  _ASLHomePageState createState() => _ASLHomePageState();
}

class _ASLHomePageState extends State<ASLHomePage> {
  final TextEditingController _textController = TextEditingController();
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String _videoUrl = '';
  String _audioUrl = '';
  VideoPlayerController? _videoController;
  AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  Future<void> startListening() async {
    bool available = await _speech.initialize(
      onStatus: (status) => print('Status: $status'),
      onError: (error) => print('Error: $error'),
    );

    if (available) {
      setState(() => _isListening = true);
      _speech.listen(
        onResult: (result) {
          setState(() {
            _textController.text = result.recognizedWords;
          });
        },
      );
    } else {
      print("Speech recognition not available");
    }
  }

  void stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> generateASLVideo() async {
    String text = _textController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please enter text or use voice input")),
      );
      return;
    }

    try {
      var response = await http.post(
        Uri.parse("http://192.168.1.102:5000/generate"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"text": text}),
      );

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        setState(() {
          _videoUrl = data['video_url'];
          _audioUrl = data['audio_url'];

          if (_videoController != null) {
            _videoController!.dispose();
          }

          _videoController = VideoPlayerController.network(_videoUrl)
            ..initialize().then((_) {
              setState(() {});
              _videoController!.play();
            });

          _audioPlayer.play(UrlSource(_audioUrl));
        });
      } else {
        print("Error: ${response.body}");
      }
    } catch (e) {
      print("Error: $e");
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Chihnam", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _textController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Enter text here",
              ),
            ),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _isListening ? null : startListening,
                  icon: Icon(Icons.mic),
                  label: Text("Start Recording"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _isListening ? stopListening : null,
                  icon: Icon(Icons.stop),
                  label: Text("Stop Recording"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: generateASLVideo,
              child: Text("Generate Video"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            ),
            SizedBox(height: 20),
            if (_videoController != null && _videoController!.value.isInitialized)
              Column(
                children: [
                  Text("Generated ASL Video", style: TextStyle(fontWeight: FontWeight.bold)),
                  AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        VideoPlayer(_videoController!),
                        Positioned(
                          bottom: 10,
                          child: FloatingActionButton(
                            backgroundColor: Colors.blue,
                            onPressed: () {
                              setState(() {
                                if (_videoController!.value.isPlaying) {
                                  _videoController!.pause();
                                } else {
                                  _videoController!.play();
                                }
                              });
                            },
                            child: Icon(
                              _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            if (_audioUrl.isNotEmpty)
              Column(
                children: [
                  Text("Generated Speech", style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: Icon(Icons.play_arrow, size: 40, color: Colors.blue),
                    onPressed: () => _audioPlayer.play(UrlSource(_audioUrl)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}