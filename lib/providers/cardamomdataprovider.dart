import 'dart:async';
import 'dart:convert';

import 'package:cardamomrate/model/cardamomdatamodel.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class CardamomDataProvider with ChangeNotifier {
  List<CardamomData> _cardamomData = [];
  bool _isLoading = false;
  bool _hasMoreData = true;
  int _currentPage = 1;
  final int _perPage = 10;
  Timer? _fetchTimer;

  List<CardamomData> get cardamomData => _cardamomData;
  bool get isLoading => _isLoading;
  bool get hasMoreData => _hasMoreData;

  CardamomDataProvider() {
    fetchCardamomData();
    _startPeriodicFetch();
  }

  Future<void> fetchCardamomData({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMoreData = true;
      _cardamomData.clear();
      notifyListeners();
    }

    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      print('No internet connection. Loading data from local storage.');
      await loadDataFromLocal();
    } else {
      print('Internet connection available. Fetching data from API.');
      await fetchFromApi();
    }
  }

  Future<void> fetchFromApi() async {
    if (_isLoading || !_hasMoreData) return;

    _isLoading = true;
    notifyListeners();

    try {
      List<CardamomData> newData =
          await fetchCardamomDataPage(_currentPage, _perPage);
      if (newData.length < _perPage) {
        _hasMoreData = false;
      }
      _cardamomData.addAll(newData);
      _currentPage++;
      await _saveDataToLocal();
    } catch (e) {
      print('Error fetching data: $e');
      _hasMoreData = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _saveDataToLocal() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String dataString =
        json.encode(_cardamomData.map((item) => item.toJson()).toList());
    await prefs.setString('cardamomData', dataString);
    print('Data saved to SharedPreferences');
  }

  Future<void> loadDataFromLocal() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? dataString = prefs.getString('cardamomData');
    if (dataString != null) {
      List<dynamic> jsonData = json.decode(dataString);
      _cardamomData =
          jsonData.map((item) => CardamomData.fromJson(item)).toList();
      notifyListeners();
      print(
          'Data loaded from SharedPreferences: ${_cardamomData.length} items');
    } else {
      print('No data found in SharedPreferences');
    }
  }

  Future<List<CardamomData>> fetchCardamomDataPage(
      int page, int perPage) async {
    final response = await http.get(Uri.parse(
        'https://tibinsunny-indianspices-api.onrender.com/cardamom/archieve?page=$page&perPage=$perPage'));

    if (response.statusCode == 200) {
      List<dynamic> body = jsonDecode(response.body);
      print('API response: ${body.length} items');
      return body.map((dynamic item) => CardamomData.fromJson(item)).toList();
    } else {
      print('Failed to load data from API: ${response.statusCode}');
      throw Exception('Failed to load data');
    }
  }

  void _startPeriodicFetch() {
    _fetchTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      print('Fetching new data from API');
      await fetchCardamomData(refresh: true);
    });
  }

  @override
  void dispose() {
    _fetchTimer?.cancel();
    super.dispose();
  }
}
