import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart' show Level;
import 'package:permission_handler/permission_handler.dart';
import 'audio_tool.dart' as audio_tool;
import 'tools.dart' as tools;


typedef Fn = void Function();

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RecordVoices',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const SoundLevelScreen(),
    );
  }
}

class SoundLevelScreen extends StatefulWidget {
  const SoundLevelScreen({super.key});

  @override
  _SoundLevelScreenState createState() => _SoundLevelScreenState();
}

class _SoundLevelScreenState extends State<SoundLevelScreen> with WidgetsBindingObserver {

  FlutterSoundRecorder _recorder = FlutterSoundRecorder(logLevel: Level.error);  //录音对象
  final FlutterSoundPlayer _mPlayer = FlutterSoundPlayer(logLevel: Level.error);  //播放器对象
  bool _mPlayerIsInited = false;  //播放器是否初始化完成
  bool _mplaybackReady = false;  //播放器是否准备完成

  String filePath = 'null';  //录音文件路径

  StreamSubscription? _mPlayerSubscription;  //播放器订阅
  double _position = 0;  //播放进度
  Timer? _timer;  //定时器

  //可观察对象，提供通知机制，当值变化通知监听该值的widget；搭配ValueListenableBuilder来监听valueNotifier
  ValueNotifier<double> _currentDb = ValueNotifier(0.0);  //当前音量
  ValueNotifier<double> _duration = ValueNotifier(0.0);  //录音时长

  @override
  void initState() {
    super.initState();  // 初始化state
    _initializePlayer();  //初始化播放器
    _requestPermissions();  //请求录音权限
    WidgetsBinding.instance.addObserver(this);  //观察者：接收应用状态变化，管理生命周期、事件等
  }

  @override
  void dispose() {
    _stopListening();  //停止监听
    _recorder.closeRecorder();  //关闭录音
    setState(() {});

    stopPlayer();  //停止播放
    cancelPlayerSubscriptions();  //取消播放器订阅
    _mPlayer.closePlayer();  //关闭播放器

    _currentDb.dispose();  //销毁对象
    WidgetsBinding.instance.removeObserver(this);  //移除观察者，防止内存泄漏
    super.dispose();  // 销毁state
  }

  void _initializePlayer() async {
    await _mPlayer.closePlayer();  //关闭播放器
    await _mPlayer.openPlayer();  //打开播放器
    await _mPlayer.setSubscriptionDuration(const Duration(milliseconds: 10));  //设置订阅持续时间
    setState(() {
      _mPlayerIsInited = true;  //播放器初始化完成
    });
  }

  void cancelPlayerSubscriptions(){
    if (_mPlayerSubscription != null){
      _mPlayerSubscription!.cancel();  //取消播放器订阅
      _mPlayerSubscription = null;  //播放器订阅取消
    }
  }

  Future<void> _requestPermissions() async {
    // 请求麦克风权限
    if (await Permission.microphone.request().isGranted) {
      await _initRecorder();  //await等待权限请求结果
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('需要麦克风权限才能使用此功能')),
      );
    }
  }

  Future<void> _initRecorder() async {
    // 初始化录音
    _recorder = FlutterSoundRecorder();

    try {
      await _recorder.openRecorder();  //打开录音
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('无法打开音频会话: $e')),
      );
    }
  }

  Future<void> _startListening() async {
    // 开始录音
    if (_mPlayer.isPlaying || _recorder.isRecording) return; // 避免重复开始和正在播放音频时候点击
    if (!(_mPlayer.isPlaying) & !(_mPlayer.isPaused) & _mPlayer.isStopped & (filePath !='null')){
      audio_tool.deleteTempFile(filePath);  // 只有在音频播放器不工作时，才删除文件
    }
    try {
      _currentDb.value = 0.0;
      _duration.value = 0.0;
      setState(() {});
      Directory? tempDir = await getExternalStorageDirectory();  // 获取临时文件的目录
      filePath = '${tempDir!.path}/temp_audio_${Random().nextInt(10000)}.wav'; // 设置临时文件路径
      await _recorder.startRecorder(
        codec: Codec.pcm16WAV,
        numChannels: 1,
        bitRate: 16000,
        sampleRate: 48000,
        toFile: filePath,
      ).then((value){setState(() {});});  // 开始录音
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('开始录音时出错: $e')),
      );
    }
  }

  Future<void> _stopListening() async {
    // 停止录音
    if (!_recorder.isRecording) return;
    try {
      await _recorder.stopRecorder();  // 停止录音
      await Future.delayed(const Duration(milliseconds: 500));  // 等待文件写入完成
      double result = await audio_tool.getAudioFilePeakDB2(filePath);
      _currentDb = ValueNotifier(result); // 处理 null 值
      _mplaybackReady = true;
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('停止录音时出错: $e')),
      );
    }
  }

  void _addListeners(){
    // 添加播放器监听
    cancelPlayerSubscriptions();
    _mPlayerSubscription = _mPlayer.onProgress!.listen((e) {
      _duration.value = e.duration.inMilliseconds.toDouble();
      if (_duration.value <= 0) _duration.value = 0.0;

      _position =
          min(e.position.inMilliseconds.toDouble(), _position);
      if (_position < 0.0) {
        _position = 0.0;
      }
    });
  }

  void play() async {
    assert(_mPlayerIsInited &&
        _mplaybackReady &&
        _recorder.isStopped &&
        _mPlayer.isStopped);
    await _mPlayer.startPlayer(
        fromDataBuffer: await File(filePath).readAsBytes(),
        sampleRate: 48000,
        codec: Codec.pcm16WAV,
        numChannels: 1,
        whenFinished: () {
          setState(() {
            _position = 0;
          });
        });
    _addListeners();
    setState(() {});
  }

  Future<void> stopPlayer() async {
    await _mPlayer.stopPlayer();
    _mPlayerSubscription?.cancel();
    _timer?.cancel();
    _position = 0;
    setState(() {});
  }

  Future<void> seekToPlayer(int milliSecs) async {
    //playerModule.logger.d('-->seekToPlayer');
    try {
      if (_mPlayer.isPlaying) {
        await _mPlayer.seekToPlayer(Duration(milliseconds: milliSecs));
      }
    } on Exception catch (err) {
      _mPlayer.logger.e('error: $err');
    }
    setState(() {});
    //playerModule.logger.d('<--seekToPlayer');
  }

  Fn? getPlaybackFn() {
    if (!_mPlayerIsInited || !_mplaybackReady || !_recorder.isStopped) {
      return null;
    }
    else{
      return _mPlayer.isStopped
          ? (){
            play();
          }
          : () {
            stopPlayer().then((value) => setState(() {}));
            };
    }
  }

  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey,
      appBar: AppBar(
        centerTitle: true,
        title: const Text('Sound dB display'),
      ),
      body: Column(
          children: [
            Container(
              margin: const EdgeInsets.all(3),
              padding: const EdgeInsets.all(3),
              height: 120,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFAF0E6),
                border: Border.all(
                  color: Colors.indigo,
                  width: 3,
                ),
              ),
              child: 
                Row(
                  children: [
                  ElevatedButton(
                  onPressed: _recorder.isRecording ? _stopListening : _startListening,
                  child: Text(_recorder.isRecording ? 'Stop' : 'Record'),
                  ),
                  const SizedBox(width: 20),
                  Text(_recorder.isRecording
                        ? 'Recording in progress'
                        : 'Recorder is stopped'),
                ],),),
            Container(
                margin: const EdgeInsets.all(3),
                padding: const EdgeInsets.all(3),
                height: 120,
                width: double.infinity,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAF0E6),
                  border: Border.all(
                    color: Colors.indigo,
                    width: 3,
                  ),
                ),
                child: ValueListenableBuilder<double>(
                valueListenable: _currentDb,
                builder: (context, currentDb, _) {
                  return Text(
                    'Recorded audio dB: ${currentDb.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red),
                  );
                },),),
            Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.all(3),
            height: 120,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF0E6),
              border: Border.all(
                color: Colors.indigo,
                width: 3,
              ),
            ),
            child: Row(children: [
              ElevatedButton(
                onPressed: getPlaybackFn(),
                child: Text(_mPlayer.isPlaying ? 'Stop' : 'Play'),
              ),
              const SizedBox(
                width: 20,
              ),
              Text(_mPlayer.isPlaying
                  ? 'Playback in progress'
                  : 'Player is stopped'),
            ]),),
            Container(
            margin: const EdgeInsets.all(3),
            padding: const EdgeInsets.all(3),
            height: 120,
            width: double.infinity,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFFAF0E6),
              border: Border.all(
                color: Colors.indigo,
                width: 3,
              ),
            ),
            child: Column(
              children: [
                const Text('Duration:'),
                Text(tools.timeformattransfer(_duration.value.toInt())),
                Slider(
                  value: min(_position, _duration.value), 
                  min: 0.0,
                  max: _duration.value,
                  onChanged: (value) async {await seekToPlayer(value.toInt());})
              ],),)
        ],),
      );
  }
}