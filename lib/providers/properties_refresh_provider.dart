import 'package:flutter/foundation.dart';

class PropertiesRefreshProvider extends ChangeNotifier {
  int _token = 0;

  int get token => _token;

  void requestRefresh() {
    _token++;
    notifyListeners();
  }
}
