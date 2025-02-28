import 'dart:io';
import 'dart:math';


const int VOLUMEMAX = 32767;

Future<List?> readAudioFile1(String filePath) async {
  List<double>? pcmData;
  try {
    final file = File(filePath);
    if (await file.exists()) {
      // 读取文件的字节内容
      List<int> bytes = await file.readAsBytes();
      print('Audio file read successfully: ${bytes.length} bytes');

      // 假设音频数据是 16 位 PCM（每个样本 2 个字节），一个字节8个bit，一个bit占一位，当一个bit有两种情况0，1
      pcmData = List<double>.filled(bytes.length ~/ 2, 0.0);  // ~/整除，Float32List是32位浮点数数组，确定数组长度
      for (int i = 0; i < bytes.length; i += 2) {
        // 将 16 位整数转换为浮点数
        int sample = (bytes[i] | (bytes[i + 1] << 8));  // 位或运算符|，合并低位直接和高位字节
        if (sample >= 32768){
          sample -= 65536;
        }

        pcmData[i ~/ 2] = (sample / VOLUMEMAX).toDouble(); // 归一化到 [-1.0, 1.0]
      }
    } else {
      print('File does not exist.');
    }
  } catch (e) {
    print('Error reading audio file: $e');
  }
  return pcmData;
}

Future<List<int>?> readAudioFile2(String filePath) async {
  List<int>? samples;

  try {
    final file = File(filePath);
    
    if (await file.exists()) {
      // 读取文件的字节内容
      List<int> bytes = await file.readAsBytes();
      print('Audio file read successfully: ${bytes.length} bytes');

      // 假设音频数据是 16 位 PCM（每个样本 2 个字节）
      samples = List<int>.filled(bytes.length ~/ 2, 0);
      for (int i = 0; i < bytes.length; i += 2) {
        // 将 16 位整数转换为原始整数值
        int sample = (bytes[i] | (bytes[i + 1] << 8));
        if (sample >= 32768) {
          sample -= 65536; // 转换为负数
        }

        samples[i ~/ 2] = sample; // 不进行归一化
      }
    } else {
      print('File does not exist.');
    }
  } catch (e) {
    print('Error reading audio file: $e');
  }
  return samples; 
}


// 计算峰值 dB 的函数
double calculatePeakDB1(List pcmData, int length) {
  double peakValue = 0.0;

  for (int i = 0; i < length; ++i) {
    peakValue = max(peakValue, pcmData[i].abs());
  }
  if (peakValue == 0.0) {
    return double.negativeInfinity;
  }

  return 20.0 * (log(peakValue) / log(10));
}

// 计算峰值 dB 的函数
double calculatePeakDB2(List<int> samples, int length) {
  
  int sum = 0;
  double? ret;

  for (int i = 0; i < length; i++) {
    sum += samples[i].abs();
  }

  ret = (sum / (samples.length * VOLUMEMAX)).toDouble();

  return 20.0 * (log(ret) / log(10));
}

Future<void> deleteTempFile(String filePath) async {
  try {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
      print('文件已删除: $filePath');
    } else {
      print('文件不存在: $filePath');
    }
  } catch (e) {
    print('删除文件时出错: $e');
  }
}

Future<double> getAudioFilePeakDB1(String filePath) async{
  
  List? pcmData = await readAudioFile1(filePath);
  
  double peakDB = calculatePeakDB1(pcmData!, pcmData.length);

  return peakDB;
}

Future<double> getAudioFilePeakDB2(String filePath) async{
  
  List<int>? pcmData = await readAudioFile2(filePath);
  
  double peakDB = calculatePeakDB2(pcmData!, pcmData.length);

  return peakDB;
}

