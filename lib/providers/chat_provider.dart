import 'package:flutter/material.dart';

class ChatProvider extends ChangeNotifier {
  int _unreadChatsCount = 0;

  int get unreadChatsCount => _unreadChatsCount;

  void setUnreadChatsCount(int count) {
    _unreadChatsCount = count;
    notifyListeners();
  }

  void incrementUnreadCount() {
    _unreadChatsCount++;
    notifyListeners();
  }

  void decrementUnreadCount() {
    if (_unreadChatsCount > 0) {
      _unreadChatsCount--;
      notifyListeners();
    }
  }

  void resetUnreadCount() {
    _unreadChatsCount = 0;
    notifyListeners();
  }
}
