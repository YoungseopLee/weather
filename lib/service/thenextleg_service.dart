// thenextleg_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class NextLegApiService {
  final String _apiEndpoint = 'https://api.thenextleg.io/v2/imagine';
  final String _authToken;

  NextLegApiService(this._authToken);

  Future<String?> generateImage(String prompt,
      {String ref = '',
      String webhookOverride = '',
      bool ignorePrefilter = false}) async {
    var headers = {
      'Authorization': 'Bearer $_authToken',
      'Content-Type': 'application/json',
    };

    var requestBody = {
      'msg': prompt,
      'ref': ref,
      'webhookOverride': webhookOverride,
      'ignorePrefilter': ignorePrefilter.toString(),
    };

    var request = http.Request('POST', Uri.parse(_apiEndpoint));
    request.body = json.encode(requestBody);
    request.headers.addAll(headers);

    try {
      http.StreamedResponse response =
          await request.send().timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        String body = await response.stream.bytesToString();
        var data = json.decode(body);
        if (data != null && data['messageId'] != null) {
          print('Image generation initiated successfully.');
          return data['messageId']; // Correct key for the messageId
        } else {
          print('The response did not contain a messageId.');
          return null;
        }
      } else {
        print(
            'Failed to initiate image generation. Status code: ${response.statusCode}.');
        return null;
      }
    } catch (e) {
      print('An exception occurred while generating image: $e');
      return null;
    }
  }

// 기존 _getImageBytes 메소드 대신 사용할 수 있는 새로운 메소드
  Future<Uint8List?> getImageBytes(String imageUrl) async {
    var headers = {
      'Authorization': 'Bearer $_authToken',
      'Content-Type': 'application/json',
    };

    var requestBody = json.encode({
      'imgUrl': imageUrl,
    });

    var response = await http.post(
      Uri.parse('https://api.thenextleg.io/getImage'),
      headers: headers,
      body: requestBody,
    );

    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      print(
          'Failed to retrieve the image safely. Status code: ${response.statusCode}.');
      return null;
    }
  }

  /*
  Future<Uint8List?> pollForImage(String messageId,
      {int maxRetries = 20, int expireMins = 2}) async {
    var pollUrl =
        'https://api.thenextleg.io/v2/message/$messageId?expireMins=$expireMins';

    var headers = {'Authorization': 'Bearer $_authToken'};
    int retryCount = 0;

    while (retryCount < maxRetries) {
      var response = await http.get(Uri.parse(pollUrl), headers: headers);
      print(
          'Polling attempt: $retryCount with status code: ${response.statusCode}'); // 로그 추가
      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data != null && data['progress'] != null) {
          int progress = data['progress'];
          print('Progress: $progress%');
          print('Response body: ${response.body}'); // 로그 추가
          if (progress == 100 && data['response'] != null) {
            // 'imageUrls'가 null이거나 비어 있는지 확인합니다.
            if (data['response']['imageUrls'] == null ||
                data['response']['imageUrls'].isEmpty) {
              print('imageUrls is null or empty in the response.');
              break;
            }
            // 'imageUrls' 배열에서 첫 번째 URL을 사용합니다.
            String imageUrl = data['response']['imageUrls'][0];
            print('Fetching image from URL: $imageUrl');
            return await getImageBytes(imageUrl);
          }
        } else {
          print(
              'The response did not contain progress or imageUrls.'); // 상세 로그 출력
        }
      } else {
        print(
            'Unexpected response status code: ${response.statusCode} with body: ${response.body}'); // 로그 추가
      }

      await Future.delayed(Duration(seconds: 5));
      retryCount++;
    }

    print(
        'Max retries exceeded or an error occurred without successful image retrieval.');
    return null;
  }
  */

  Future<List<Uint8List?>> pollForImages(String messageId,
      {int maxRetries = 20, int expireMins = 2}) async {
    var pollUrl =
        'https://api.thenextleg.io/v2/message/$messageId?expireMins=$expireMins';
    var headers = {'Authorization': 'Bearer $_authToken'};
    int retryCount = 0;
    List<Uint8List?> imageBytesList = [];

    while (retryCount < maxRetries) {
      var response = await http.get(Uri.parse(pollUrl), headers: headers);
      print(
          'Polling attempt: $retryCount with status code: ${response.statusCode}'); // 로그 추가

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        if (data['progress'] == 100 && data['response'] != null) {
          int progress = data['progress'];
          print('Progress: $progress%');
          print('Response body: ${response.body}'); // 로그 추가
          List<String> imageUrls = List.from(data['response']['imageUrls']);
          for (String imageUrl in imageUrls) {
            Uint8List? imageBytes = await getImageBytes(imageUrl);
            if (imageBytes != null) {
              imageBytesList.add(imageBytes);
            }
          }
          return imageBytesList; // 모든 이미지 데이터를 리스트에 담아 반환
        }
      } else {
        print('Unexpected response status code: ${response.statusCode}');
      }
      await Future.delayed(Duration(seconds: 5));
      retryCount++;
    }
    print('Failed to retrieve images or max retries exceeded.');
    return imageBytesList; // 이미지를 가져오는데 실패하면 빈 리스트 반환
  }
}
