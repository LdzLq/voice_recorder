#include <stdio.h>
#include <stdlib.h>
#include <math.h>

// 计算PCM数据的峰值分贝数
double calculatePeakDB(const float *pcmData, size_t length) {
    // 查找最大绝对值
    float peakValue = 0.0f;
    for (size_t i = 0; i < length; ++i) {
        if (fabs(pcmData[i]) > peakValue) {
            peakValue = fabs(pcmData[i]);
        }
    }
    // 如果峰值为0，则返回负无穷大
    if (peakValue == 0.0f) {
        return -INFINITY;
    }
    // 计算峰值分贝数
    double peakDB = 20.0 * log10(peakValue);
    return peakDB;
}

int main() {
    // 示例PCM数据 (float 格式，范围 -1.0 到 1.0)
    float pcmData[] = { 0.0f, 0.1f, -0.5f, 0.3f, -0.9f, 0.8f };
    size_t length = sizeof(pcmData) / sizeof(pcmData[0]);
    // 计算峰值分贝数
    double peakDB = calculatePeakDB(pcmData, length);
    printf("Peak dB: %.2f dB\n", peakDB);
    return 0;
}