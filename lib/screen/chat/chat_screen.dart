import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';


class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  String username;
  String _lastMessage = '';

  double _fontSize = 16.0;

  int _sameMessageCount = 0;

  WebSocketChannel channel;
  TextEditingController _textEditingController;
  TextEditingController _textUsername;
  ScrollController _scrollController = ScrollController();

  final List<String> _messages = <String>[];
  final int _maxSameMessageCount = 4;

  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;
  AppLifecycleState _appLifecycleState;

  @override
  void initState() {
    super.initState();

    _fontSize = 16.0;

    _textEditingController = TextEditingController();
    _textUsername = TextEditingController();

    connectToWebSocket();

    var initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettingsIOS = IOSInitializationSettings();
    var initializationSettings = InitializationSettings(initializationSettingsAndroid,initializationSettingsIOS);
    flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      setUsername();
    });
  }

  @override
  void dispose() {
    channel.sink.close();
    _textEditingController.dispose();
    _textUsername.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    setState(() {
      _appLifecycleState = state;
    });
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        bool shouldQuit = await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Confirm exit'),
              content: Text('Are you sure you want to exit the app?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    channel.sink.close();
                    Navigator.of(context).pop(true);
                  },
                  child: Text('Exit'),
                ),
              ],
            );
          },
        );
        return shouldQuit ?? false;
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          title: Text(
            'Lobby',
            style: TextStyle(color: Colors.black),
          ),
          actions: [
            PopupMenuButton(
              icon: Icon(Icons.more_vert, color: Colors.black45),
              itemBuilder: (BuildContext context) => <PopupMenuEntry>[
                PopupMenuItem(
                  child: ListTile(
                    leading: Icon(Icons.wifi_protected_setup),
                    title: Text('Reconnect'),
                    onTap: () {
                      Navigator.pop(context);

                      if (username == null) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          setUsername();
                        });
                      }
                      reconnectToWebSocket();
                    },
                  ),
                ),
                PopupMenuItem(
                  child: ListTile(
                    leading: Icon(Icons.person),
                    title: Text('Change Name'),
                    onTap: () {
                      // Do something when Item 2 is tapped
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        setUsername();
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
                PopupMenuItem(
                  child: ListTile(
                    leading: Icon(Icons.restore_from_trash),
                    title: Text('Clear Chat'),
                    onTap: () {
                      // Do something when Item 2 is tapped
                      setState(() {
                        _messages.clear();
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
                PopupMenuItem(
                  child: ListTile(
                    leading: Icon(Icons.settings),
                    title: Text('Setting'),
                    onTap: () {
                      // Do something when Item 2 is tapped
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        _showFontSizePickerDialog();
                      });
                      Navigator.pop(context);
                    },
                  ),
                ),
                PopupMenuItem(
                  child: ListTile(
                    leading: Icon(Icons.exit_to_app),
                    title: Text('Exit'),
                    onTap: () {
                      // Do something when Item 3 is tapped
                      Navigator.pop(context);
                      exit(0);
                    },
                  ),
                ),
              ],
            )
          ],
        ),
        body: Column(
          children: [
            SizedBox(
              height: 10.0,
            ),
            Expanded(
              child: Scrollbar(
                thickness: 10.0,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (BuildContext context, int index) {
                    Map<String, dynamic> textData = jsonDecode(_messages[index]);
                    String from = textData['from'];
                    String messageText = textData['message'];
                    String displayText;

                    if (from == username) {
                      displayText = '$messageText : [You]';
                    } else {
                      displayText = '[ $from ] : $messageText';
                    }

                    if (from == username) {
                      return Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 1.0, horizontal: 8.0),
                          child: Text(
                            displayText,
                            style: TextStyle(fontSize: _fontSize),
                          ),
                        ),
                      );
                    } else {
                      if ( from == 'Client'){
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 1.0, horizontal: 8.0),
                            child: Text(
                              displayText,
                              style: TextStyle(fontSize: _fontSize),
                            ),
                          ),
                        );
                      } else {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 1.0, horizontal: 8.0),
                            child: Text(
                              displayText,
                              style: TextStyle(fontSize: _fontSize),
                            ),
                          ),
                        );
                      }
                    }
                  },
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: TextField(
                      controller: _textEditingController,
                      maxLength: 70,
                      maxLengthEnforcement: MaxLengthEnforcement.none,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (String value) {
                        _sendMessage();
                      },
                      decoration: InputDecoration(
                        hintText: 'Enter a message',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                      onEditingComplete: () {},
                    ),
                  ),
                ),
                ElevatedButton(
                  child: Text('Send'),
                  style: ButtonStyle(
                      backgroundColor: MaterialStateProperty.resolveWith(
                          (states) => Colors.black45)),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> showNotification(String title, String body) async {
    if (_appLifecycleState != null &&
        _appLifecycleState != AppLifecycleState.resumed) {
      // Only show the notification if the app is not in the foreground
      var androidPlatformChannelSpecifics = AndroidNotificationDetails(
          "anonchat_channel_id",
          "AnonChat! Notifications",
          "Notifications for AnonChat!",
          importance: Importance.Max, priority: Priority.High, ticker: 'ticker');
      var iOSPlatformChannelSpecifics = IOSNotificationDetails();
      var platformChannelSpecifics = NotificationDetails(
          androidPlatformChannelSpecifics,
          iOSPlatformChannelSpecifics);
      await flutterLocalNotificationsPlugin.show(
          0, title, body, platformChannelSpecifics,
          payload: 'item x');
    }
  }

  void _showFontSizePickerDialog() async {
    final selectedFontSize = await showDialog<double>(
      context: context,
      builder: (context) => FontSizePickerDialog(initialFontSize: _fontSize),
    );

    if (selectedFontSize != null) {
      setState(() {
        _fontSize = selectedFontSize;
      });
    }
  }

  void setUsername() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => SimpleDialog(
        title: Text('anonChat!'),
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 4.0),
            child: TextField(
              controller: _textUsername,
              maxLength: 8,
              maxLengthEnforcement: MaxLengthEnforcement.none,
              textInputAction: TextInputAction.send,
              onSubmitted: (String value) {
                if (_textUsername.text.isNotEmpty &&
                    !_textUsername.text.toLowerCase().contains('server') &&
                    !_textUsername.text.toLowerCase().contains('client') &&
                    !_textUsername.text.toLowerCase().contains('admin')) {
                  _setUsername();
                  Navigator.pop(context);
                } else {}
              },
              decoration: InputDecoration(
                hintText: 'Enter a username',
                border: OutlineInputBorder(),
                counterText: '',
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 16.0),
            child: ElevatedButton(
              child: Text(
                'Enter',
                style: TextStyle(color: Colors.white),
              ),
              style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.resolveWith(
                      (states) => Colors.black45)),
              onPressed: () {
                if (_textUsername.text.isNotEmpty &&
                    !_textUsername.text.toLowerCase().contains('server') &&
                    !_textUsername.text.toLowerCase().contains('client') &&
                    !_textUsername.text.toLowerCase().contains('admin')) {
                  _setUsername();
                  Navigator.pop(context);
                } else {}
              },
            ),
          ),
        ],
      ),
    );
  }

  void connectToWebSocket() {
    channel = WebSocketChannel.connect(Uri.parse('ws://203.175.11.220:1324'));
    channel.stream.listen(
          (data) {
        setState(() {
          _messages.add(data);
          _toBottom();
        });
        // Scroll to the bottom if _shouldScroll is true
        Map<String, dynamic> wsData = jsonDecode(data);
        showNotification(wsData['from'], wsData['message']);
          },
      onError: (error, stackTrace) {
        // Handle error when the WebSocket connection fails
        print('Error connecting to WebSocket server: $error');
        setState(() {
          _messages.add(
              '{"from": "Server", "message": "Error connecting to anonChat server: $error"}');
          _toBottom();
        });
        showNotification("Error", "Error connecting to WebSocket server: $error");
      },
      onDone: () {
        // Handle when the WebSocket connection is closed
        print('WebSocket connection closed');
        setState(() {
          _messages.add(
              '{"from": "Server", "message": "anonChat! server connection closed"}');
          _toBottom();
        });
        showNotification("Connection Closed", "WebSocket connection closed");
      },
    );
  }

  void reconnectToWebSocket() {
    channel.sink.close();
    connectToWebSocket();
    _toBottom();
  }

  void _sendMessage() {
    String message = _textEditingController.text;
    if (username == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setUsername();
      });
    }
    if (message.isNotEmpty) {
      if (message == _lastMessage) {
        if (_sameMessageCount < _maxSameMessageCount) {
          _sameMessageCount++;
        }
      } else {
        _lastMessage = message;
        _sameMessageCount = 1;
      }

      if (_sameMessageCount != _maxSameMessageCount) {
        channel.sink.add(jsonEncode(
            '{"from": "' + username + '", "message": "' + message + '"}'));
      }
      if (_sameMessageCount == _maxSameMessageCount) {
        setState(() {
          _messages.add('{"from": "Client", "message": "SPAM ALERT!"}');
        });
      }
      _toBottom();
      _textEditingController.clear();
    }
  }

  void _setUsername() {
    username = _textUsername.text;
    setState(() {
      _messages.add(
          '{"from": "Client", "message": "Success set username to [ $username ]"}');
    });
    _toBottom();
    _textUsername.clear();
  }

  void _toBottom() {
    _scrollController.animateTo(_scrollController.position.maxScrollExtent + 25,
        duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    Scrollable.ensureVisible(context);
  }
}

// move the dialog into it's own stateful widget.
// It's completely independent from your page
// this is good practice
class FontSizePickerDialog extends StatefulWidget {
  final double initialFontSize;

  const FontSizePickerDialog({Key key, this.initialFontSize}) : super(key: key);

  @override
  _FontSizePickerDialogState createState() => _FontSizePickerDialogState();
}

class _FontSizePickerDialogState extends State<FontSizePickerDialog> {
  double _fontSize;
  double _initialFontSize;


  @override
  void initState() {
    super.initState();
    _fontSize = widget.initialFontSize;
    _initialFontSize = widget.initialFontSize;
  }

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: Text('Font Size'),
      children: [
        Container(
          child: Slider(
            value: _fontSize,
            min: 8,
            max: 32,
            divisions: 3,
            onChanged: (value) {
              setState(() {
                _fontSize = value;
              });
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: () {
                setState(() {
                  _fontSize = _initialFontSize;
                });
              },
              child: Text('RESET'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, _fontSize);
              },
              child: Text('DONE'),
            ),
          ],
        ),
      ],
    );
  }
}