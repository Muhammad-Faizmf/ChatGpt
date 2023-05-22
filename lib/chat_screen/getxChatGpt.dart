import 'package:connectivity/connectivity.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Message {
  final String role;
  final String content;

  Message(this.role, this.content);
}

class ChatController extends GetxController {
  RxList<Message> messages = <Message>[].obs;
  var isMessageEmpty = true.obs;
  final _isFetching = false.obs;
  RxBool connectivityStatus = true.obs;

  @override
  void onInit() {
    super.onInit();
    checkConnectivity();
  }

  void checkConnectivity() async {
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      connectivityStatus.value = false;
    } else {
      connectivityStatus.value = true;
    }
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result == ConnectivityResult.none) {
        connectivityStatus.value = false;
      } else {
        connectivityStatus.value = true;
      }
    });
  }

  void sendMessage(String content) async {
    if (content.isEmpty) return;

    final message = Message('user', content);
    messages.add(message);

    _isFetching.value = true;

    final response = await getChatbotResponse(content);
    final botMessage = Message('bot', response);
    messages.add(botMessage);
    _isFetching.value = false;
  }

  Future<String> getChatbotResponse(String message) async {
    const url = 'https://api.openai.com/v1/chat/completions';
    const apiKey = ''; // Replace with your ChatGPT API key

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        "model": "gpt-3.5-turbo",
        'messages': [
          {'role': 'system', 'content': 'You: $message'},
        ]
      }),
    );
    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final choices = jsonResponse['choices'];
      if (choices.isNotEmpty) {
        return choices[0]['message']['content'];
      }
    }

    throw Exception('Failed to send message: ${response.statusCode}');
  }
}

class ChatPage extends StatefulWidget {
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatController _chatController = Get.put(ChatController());

  final TextEditingController _textEditingController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text('ChatGPT'),
      ),
      body: Column(
        children: [
          Expanded(
              child: Obx(() => (_chatController.connectivityStatus.value ==
                      false
                  ? Center(
                      child: Container(
                          padding: const EdgeInsets.all(20.0),
                          color: Colors.red,
                          child: const Text("No internet connection.",
                              style: TextStyle(color: Colors.white))))
                  : GetX<ChatController>(
                      builder: (_) {
                        return ListView.builder(
                          controller: _scrollController,
                          itemCount: _chatController.messages.length,
                          itemBuilder: (context, index) {
                            final message = _chatController.messages[index];
                            final decodedContent =
                                utf8.decode(message.content.runes.toList());
                            return Container(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 10.0, horizontal: 5.0),
                              alignment: message.role == "user"
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 10.0),
                                decoration: message.role == "user"
                                    ? const BoxDecoration(
                                        color: Colors.blue,
                                        borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(10.0),
                                            topRight: Radius.circular(20.0),
                                            bottomLeft: Radius.circular(10.0)),
                                      )
                                    : BoxDecoration(
                                        color: Colors.grey[300],
                                        borderRadius: const BorderRadius.only(
                                            topLeft: Radius.circular(20.0),
                                            topRight: Radius.circular(15.0),
                                            bottomRight: Radius.circular(15.0)),
                                      ),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onLongPress: () {
                                    Clipboard.setData(
                                        ClipboardData(text: decodedContent));
                                    Fluttertoast.showToast(
                                        msg: "Message Copied",
                                        toastLength: Toast.LENGTH_SHORT,
                                        gravity: ToastGravity.CENTER,
                                        timeInSecForIosWeb: 1,
                                        backgroundColor: Colors.red,
                                        textColor: Colors.white,
                                        fontSize: 16.0);
                                  },
                                  child: Text(
                                    decodedContent,
                                    style: TextStyle(
                                        fontSize: 16.0,
                                        color: message.role == "user"
                                            ? Colors.white
                                            : Colors.black),
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    )))),
          Obx(() => _chatController._isFetching.value
              ? Container(
                  margin: const EdgeInsets.symmetric(vertical: 10.0),
                  child: const SpinKitCircle(
                    color: Colors.red,
                  ))
              : Container()),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Obx(() => TextField(
                        maxLines: 5,
                        minLines: 1,
                        enabled:
                            _chatController.connectivityStatus.value == false
                                ? false
                                : true,
                        onChanged: (value) {
                          if (value.isEmpty) {
                            _chatController.isMessageEmpty.value = true;
                          } else {
                            _chatController.isMessageEmpty.value = false;
                          }
                          _scrollToBottom();
                        },
                        controller: _textEditingController,
                        decoration: const InputDecoration(
                            hintText: 'Type your message...',
                            contentPadding: EdgeInsets.symmetric(
                                vertical: 10.0, horizontal: 12.0),
                            border: OutlineInputBorder()),
                      )),
                ),
                Obx(() => IconButton(
                      icon: const Icon(
                        Icons.send,
                        size: 30.0,
                      ),
                      onPressed: _chatController.isMessageEmpty.value == true
                          ? null
                          : () {
                              _chatController
                                  .sendMessage(_textEditingController.text);
                              _textEditingController.clear();
                              _chatController.isMessageEmpty.value = true;
                              FocusScope.of(context).unfocus();
                            },
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }
}
