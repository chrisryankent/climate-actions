import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:url_launcher/url_launcher.dart';

const String weatherCheckTask = "weatherCheckTask";

// Global instance for notifications.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// This is the callback function that Workmanager will call in the background.
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == weatherCheckTask) {
      try {
        // For background checks, using a default city (London).
        final response = await http.get(Uri.parse(
            'https://api.openweathermap.org/data/2.5/weather?q=Kampala&appid=7401dd13450118544c831cb224c24440'));
        if (response.statusCode == 200) {
          Map<String, dynamic> weather = json.decode(response.body);
          String condition =
              weather['weather'][0]['description'].toString().toLowerCase();
          if (condition.contains('rain') ||
              condition.contains('storm') ||
              condition.contains('extreme')) {
            var androidDetails = AndroidNotificationDetails(
              'weather_channel',
              'Weather Alerts',
              channelDescription: 'Notifications for severe weather alerts',
              importance: Importance.max,
              priority: Priority.high,
            );
            var notificationDetails =
                NotificationDetails(android: androidDetails);
            await flutterLocalNotificationsPlugin.show(
              0,
              'Severe Weather Alert',
              'Current weather: ${weather['weather'][0]['description']}. Stay safe!',
              notificationDetails,
            );
          }
        }
      } catch (e) {
        print("Background task error: $e");
      }
    }
    return Future.value(true);
  });
}

Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeNotifications();
  // Initialize background task manager using an instance.
  Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  Workmanager().registerPeriodicTask(
    "1",
    weatherCheckTask,
    frequency: const Duration(hours: 1),
  );
  runApp(const ClimateActionApp());
}

class ClimateActionApp extends StatelessWidget {
  const ClimateActionApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Climate Action',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.green[700],
          centerTitle: true,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.green[700],
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
        ),
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Map<String, dynamic>? weatherData;
  Map<String, dynamic>? forecastData;
  Map<String, dynamic>? carbonData;

  // Controllers for Footprint Calculator
  final TextEditingController _electricityController = TextEditingController();
  final TextEditingController _gasController = TextEditingController();
  final TextEditingController _travelController = TextEditingController();
  double? _footprintResult;

  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetchAllData();
  }

  Future<void> _fetchAllData() async {
    await _fetchWeatherData();
    await _fetchForecastData();
    await _fetchCarbonData();
  }

  Future<void> _fetchWeatherData() async {
    try {
      Position position = await _determinePosition();
      final url =
          'https://api.openweathermap.org/data/2.5/weather?lat=${position.latitude}&lon=${position.longitude}&appid=7401dd13450118544c831cb224c24440';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          weatherData = json.decode(response.body);
          // Convert temperature to Celsius
          weatherData!['main']['temp'] =
              (weatherData!['main']['temp'] - 273.15).toStringAsFixed(1);
        });
      } else {
        throw Exception('Failed to load weather data');
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _fetchForecastData() async {
    try {
      Position position = await _determinePosition();
      final url =
          'https://api.openweathermap.org/data/2.5/forecast?lat=${position.latitude}&lon=${position.longitude}&appid=7401dd13450118544c831cb224c24440';
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        setState(() {
          forecastData = json.decode(response.body);
          // Convert temperatures in the forecast to Celsius
          for (var forecast in forecastData!['list']) {
            forecast['main']['temp'] =
                (forecast['main']['temp'] - 273.15).toStringAsFixed(1);
          }
        });
      } else {
        throw Exception('Failed to load forecast data');
      }
    } catch (e) {
      print(e);
    }
  }

  Future<void> _fetchCarbonData() async {
    final url = 'https://api.carbonintensity.org.uk/intensity/date';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      setState(() {
        carbonData = json.decode(response.body);
      });
    } else {
      throw Exception('Failed to load carbon data');
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Location services are disabled.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, cannot request permissions.');
    }
    return await Geolocator.getCurrentPosition();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // --- Dashboard Page ---
  Widget _buildDashboardPage() {
    List<Widget> dashboardWidgets = [
      Text(
        'Dashboard',
        style: Theme.of(context)
            .textTheme
            .headlineSmall
            ?.copyWith(color: Colors.green[800]),
      ),
      const SizedBox(height: 16),
      _buildWeatherCard(),
      const SizedBox(height: 16),
      _buildForecastChartCard(),
      const SizedBox(height: 16),
      buildCarbonDataCard(),
      const SizedBox(height: 16),
      buildNewsCard(),
      const SizedBox(height: 16),
      buildClimateAlertCard(),
      const SizedBox(height: 16),
      buildPublicAwarenessCard(),
    ];

    // If weather indicates storm or rain, add a GeoStorm chart.
    if (weatherData != null) {
      String condition =
          weatherData!['weather'][0]['description'].toString().toLowerCase();
      if (condition.contains("storm") || condition.contains("rain")) {
        dashboardWidgets.add(const SizedBox(height: 16));
        dashboardWidgets.add(buildGeostormChartCard());
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: dashboardWidgets),
    );
  }

  Widget _buildWeatherCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.greenAccent, Colors.green],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: weatherData != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.wb_sunny, color: Colors.white, size: 28),
                      SizedBox(width: 8),
                      Text('Current Weather',
                          style: TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text('Temperature: ${weatherData!['main']['temp']}°C',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16)),
                  Text(
                      'Condition: ${weatherData!['weather'][0]['description']}',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16)),
                  Text('Humidity: ${weatherData!['main']['humidity']}%',
                      style:
                          const TextStyle(color: Colors.white, fontSize: 16)),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildForecastChartCard() {
    List<FlSpot> spots = [];
    if (forecastData != null) {
      final List forecasts = forecastData!['list'];
      for (int i = 0; i < forecasts.length && i < 8; i++) {
        // Ensure the temperature is parsed as a double
        double temp =
            double.tryParse(forecasts[i]['main']['temp'].toString()) ?? 0.0;
        spots.add(FlSpot(i.toDouble(), temp));
      }
    }
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.show_chart, color: Colors.deepOrange, size: 28),
                SizedBox(width: 8),
                Text('Temperature Forecast',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: spots.isNotEmpty
                  ? LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          getDrawingHorizontalLine: (value) {
                            return FlLine(
                                color: Colors.grey.withOpacity(0.3),
                                strokeWidth: 1);
                          },
                          getDrawingVerticalLine: (value) {
                            return FlLine(
                                color: Colors.grey.withOpacity(0.3),
                                strokeWidth: 1);
                          },
                        ),
                        titlesData: FlTitlesData(
                          bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true, reservedSize: 30)),
                          leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: true, reservedSize: 40)),
                        ),
                        borderData: FlBorderData(
                            show: true,
                            border: Border.all(
                                color: Colors.grey.withOpacity(0.4))),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            gradient: const LinearGradient(
                              colors: [Colors.deepOrange, Colors.orangeAccent],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            barWidth: 4,
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  Colors.deepOrange.withOpacity(0.3),
                                  Colors.orangeAccent.withOpacity(0.1)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            dotData: const FlDotData(show: true),
                          )
                        ],
                      ),
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildCarbonDataCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: carbonData != null
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.eco, color: Colors.teal, size: 28),
                      SizedBox(width: 8),
                      Text('Carbon Intensity',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Current: ${carbonData!['data'][0]['intensity']['actual']} gCO₂/kWh',
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    'Forecast: ${carbonData!['data'][0]['intensity']['forecast']} gCO₂/kWh',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget buildNewsCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.lightBlueAccent, Colors.blue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                Icon(Icons.newspaper, color: Colors.white, size: 28),
                SizedBox(width: 8),
                Text('Climate News',
                    style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            SizedBox(height: 12),
            Text(
              'Stay updated with the latest climate news and events. Renewable energy sources are gaining traction as governments invest in green technologies.',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // New: Climate Alerts Card with "Learn More" link.
  Widget buildClimateAlertCard() {
    String alertMessage = "No severe climate alerts at the moment.";
    if (weatherData != null) {
      String condition =
          weatherData!['weather'][0]['description'].toString().toLowerCase();
      if (condition.contains("storm") ||
          condition.contains("extreme") ||
          condition.contains("heavy") ||
          condition.contains("thunder")) {
        alertMessage =
            "Severe weather alert: ${weatherData!['weather'][0]['description']}. Stay indoors and follow official guidance.";
      }
    }
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.redAccent, Colors.red],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.warning, color: Colors.white, size: 28),
                SizedBox(width: 8),
                Text("Climate Alerts",
                    style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              alertMessage,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
              ),
              onPressed: () async {
                const url = 'https://www.un.org/en/climatechange';
                if (await canLaunch(url)) {
                  await launch(url);
                } else {
                  throw 'Could not launch $url';
                }
              },
              child:
                  const Text("Learn More", style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  // New: Public Awareness Card with "Get Involved" link.
  Widget buildPublicAwarenessCard() {
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.deepPurpleAccent, Colors.deepPurple],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.campaign, color: Colors.white, size: 28),
                SizedBox(width: 8),
                Text("Public Awareness",
                    style: TextStyle(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Join the movement for a sustainable future. Spread awareness, engage with local communities, and participate in climate action initiatives.",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
              ),
              onPressed: () async {
                const url = 'https://www.climatechange.org/';
                if (await canLaunch(url)) {
                  await launch(url);
                } else {
                  throw 'Could not launch $url';
                }
              },
              child: const Text("Get Involved",
                  style: TextStyle(color: Colors.deepPurple)),
            ),
          ],
        ),
      ),
    );
  }

  // New: GeoStorm Analysis Chart (if storm/rain detected)
  Widget buildGeostormChartCard() {
    // Dummy data representing storm intensity trends.
    List<FlSpot> stormSpots = [
      const FlSpot(0, 10),
      const FlSpot(1, 20),
      const FlSpot(2, 15),
      const FlSpot(3, 25),
      const FlSpot(4, 20),
    ];
    return Card(
      elevation: 5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.cloud, color: Colors.blue, size: 28),
                SizedBox(width: 8),
                Text('GeoStorm Analysis',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: true),
                  titlesData: FlTitlesData(show: true),
                  borderData: FlBorderData(show: true),
                  lineBarsData: [
                    LineChartBarData(
                      spots: stormSpots,
                      isCurved: true,
                      gradient: const LinearGradient(
                        colors: [Colors.blue, Colors.lightBlueAccent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      barWidth: 4,
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            Colors.blue.withOpacity(0.3),
                            Colors.lightBlueAccent.withOpacity(0.1)
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      dotData: const FlDotData(show: true),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Analytics Page ---
  Widget buildAnalyticsPage() {
    List<FlSpot> carbonSpots = [];
    if (carbonData != null) {
      final List data = carbonData!['data'];
      for (int i = 0; i < data.length; i++) {
        double intensity = (data[i]['intensity']['actual'] ?? 0.0) + 0.0;
        carbonSpots.add(FlSpot(i.toDouble(), intensity));
      }
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Advanced Analytics',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.deepPurple)),
          const SizedBox(height: 16),
          Card(
            elevation: 5,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: carbonSpots.isNotEmpty
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Carbon Intensity Over Time',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 220,
                          child: LineChart(
                            LineChartData(
                              gridData: FlGridData(
                                show: true,
                                drawVerticalLine: true,
                                getDrawingHorizontalLine: (value) {
                                  return FlLine(
                                      color: Colors.grey.withOpacity(0.3),
                                      strokeWidth: 1);
                                },
                                getDrawingVerticalLine: (value) {
                                  return FlLine(
                                      color: Colors.grey.withOpacity(0.3),
                                      strokeWidth: 1);
                                },
                              ),
                              titlesData: FlTitlesData(
                                bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: true, reservedSize: 30)),
                                leftTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                        showTitles: true, reservedSize: 40)),
                              ),
                              borderData: FlBorderData(
                                  show: true,
                                  border: Border.all(
                                      color: Colors.grey.withOpacity(0.4))),
                              lineBarsData: [
                                LineChartBarData(
                                  spots: carbonSpots,
                                  isCurved: true,
                                  gradient: const LinearGradient(
                                    colors: [
                                      Colors.deepPurple,
                                      Colors.purpleAccent
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  barWidth: 4,
                                  belowBarData: BarAreaData(
                                    show: true,
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.deepPurple.withOpacity(0.3),
                                        Colors.purpleAccent.withOpacity(0.1)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                  ),
                                  dotData: const FlDotData(show: true),
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : const Center(child: CircularProgressIndicator()),
            ),
          ),
        ],
      ),
    );
  }

  // --- Footprint Calculator Page ---
  Widget buildFootprintPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Footprint Calculator',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(color: Colors.orange[800])),
          const SizedBox(height: 16),
          Card(
            elevation: 5,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _electricityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Electricity (kWh)',
                      prefixIcon: Icon(Icons.electrical_services),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _gasController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Gas (m³)',
                      prefixIcon: Icon(Icons.local_fire_department),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _travelController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Monthly Travel (km)',
                      prefixIcon: Icon(Icons.directions_car),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: calculateFootprint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[800],
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Calculate Footprint'),
                  ),
                  const SizedBox(height: 20),
                  if (_footprintResult != null)
                    Text(
                      'Your estimated monthly carbon footprint is ${_footprintResult!.toStringAsFixed(2)} kg CO₂',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void calculateFootprint() {
    double electricity =
        double.tryParse(_electricityController.text.trim()) ?? 0.0;
    double gas = double.tryParse(_gasController.text.trim()) ?? 0.0;
    double travel = double.tryParse(_travelController.text.trim()) ?? 0.0;
    setState(() {
      _footprintResult = electricity * 0.5 + gas * 2.5 + travel * 0.2;
    });
  }

  // --- Energy Saving Tips Page ---
  Widget buildTipsPage() {
    String tip =
        'General energy saving tips: Turn off unused appliances, switch to LED lights, and optimize your thermostat settings.';
    if (weatherData != null) {
      // Parse the temperature back to a double
      double temp = double.tryParse(weatherData!['main']['temp']) ?? 0.0;
      if (temp > 30) {
        // Adjusted for Celsius
        tip =
            'It’s hot outside—consider using natural ventilation and fans to reduce air conditioner usage.';
      } else if (temp < 10) {
        // Adjusted for Celsius
        tip =
            'It’s cool outside—make the most of natural sunlight and reduce heating costs.';
      }
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.tealAccent, Colors.teal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.tips_and_updates, color: Colors.white, size: 28),
                  SizedBox(width: 8),
                  Text('Energy Saving Tips',
                      style: TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Text(tip,
                  style: const TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildAIQuestionDialog() {
    final TextEditingController queryController = TextEditingController();

    Future<String> generateAIResponse(String query) async {
      query = query.toLowerCase();

      // Extract location from the query
      String? location;
      if (query.contains("in")) {
        final parts = query.split("in");
        if (parts.length > 1) {
          location = parts[1].trim();
        }
      }

      if (query.contains("weather")) {
        if (location != null && location.isNotEmpty) {
          // Fetch weather data for the specified location
          try {
            final url =
                'https://api.openweathermap.org/data/2.5/weather?q=$location&appid=7401dd13450118544c831cb224c24440';
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              final description = data['weather'][0]['description'];
              final temp = (data['main']['temp'] - 273.15).toStringAsFixed(1);
              final humidity = data['main']['humidity'];
              final windSpeed = data['wind']['speed'];
              return "The current weather in $location is $description with a temperature of $temp°C. "
                  "The humidity is $humidity%, and the wind speed is $windSpeed m/s.";
            } else {
              return "Sorry, I couldn't fetch the weather data for $location. Please check the location name and try again.";
            }
          } catch (e) {
            return "An error occurred while fetching the weather data for $location. Please try again later.";
          }
        } else {
          return "Please specify a location to get the weather information. For example, 'What's the weather in London?'.";
        }
      } else if (query.contains("climate change")) {
        return "Climate change refers to long-term shifts in temperatures and weather patterns, primarily caused by human activities such as burning fossil fuels, deforestation, and industrial processes. "
            "It leads to rising global temperatures, melting ice caps, rising sea levels, and more frequent extreme weather events. "
            "To combat climate change, we need to reduce greenhouse gas emissions, transition to renewable energy, and adopt sustainable practices.";
      } else if (query.contains("carbon")) {
        if (carbonData != null) {
          return "The current carbon intensity is ${carbonData!['data'][0]['intensity']['actual']} gCO₂/kWh. "
              "This indicates the amount of carbon dioxide emitted per unit of electricity consumed. Lower carbon intensity values are better for the environment.";
        } else {
          return "Sorry, I couldn't fetch the carbon data right now. Please try again later.";
        }
      } else if (query.contains("tips")) {
        return "Here are some tips to reduce your carbon footprint:\n"
            "- Use energy-efficient appliances and LED lighting.\n"
            "- Reduce, reuse, and recycle to minimize waste.\n"
            "- Use public transportation, carpool, or switch to electric vehicles.\n"
            "- Support renewable energy sources like solar and wind power.\n"
            "- Plant trees and support reforestation projects.";
      } else if (query.contains("forecast")) {
        if (location != null && location.isNotEmpty) {
          // Fetch forecast data for the specified location
          try {
            final url =
                'https://api.openweathermap.org/data/2.5/forecast?q=$location&appid=7401dd13450118544c831cb224c24440';
            final response = await http.get(Uri.parse(url));
            if (response.statusCode == 200) {
              final data = json.decode(response.body);
              final List forecasts = data['list'];
              String forecastDetails =
                  "Here is the weather forecast for $location:\n";
              for (int i = 0; i < forecasts.length && i < 5; i++) {
                final forecast = forecasts[i];
                final time =
                    DateTime.fromMillisecondsSinceEpoch(forecast['dt'] * 1000);
                final temp =
                    (forecast['main']['temp'] - 273.15).toStringAsFixed(1);
                final condition = forecast['weather'][0]['description'];
                forecastDetails += "- ${time.hour}:00: $temp°C, $condition\n";
              }
              return forecastDetails;
            } else {
              return "Sorry, I couldn't fetch the forecast data for $location. Please check the location name and try again.";
            }
          } catch (e) {
            return "An error occurred while fetching the forecast data for $location. Please try again later.";
          }
        } else {
          return "Please specify a location to get the forecast information. For example, 'What's the forecast in New York?'.";
        }
      } else if (query.contains("extreme weather")) {
        return "Extreme weather events include hurricanes, tornadoes, heatwaves, and heavy rainfall. These events are becoming more frequent and intense due to climate change. "
            "To stay safe, monitor weather alerts, prepare emergency kits, and follow local authorities' guidance.";
      } else if (query.contains("global warming")) {
        return "Global warming refers to the long-term increase in Earth's average surface temperature due to human activities, primarily the release of greenhouse gases like carbon dioxide and methane. "
            "It leads to melting glaciers, rising sea levels, and disruptions in ecosystems. Reducing emissions and transitioning to renewable energy are key to addressing global warming.";
      } else {
        return "I'm sorry, I don't have an answer for that. Please try asking about the weather, climate change, carbon intensity, or energy-saving tips.";
      }
    }

    return AlertDialog(
      title: const Text("AI Climate Assistant"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "Ask me anything about the current weather, climate change, or carbon intensity!",
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: queryController,
            decoration: const InputDecoration(
              labelText: "Your question",
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final query = queryController.text.trim();
            if (query.isNotEmpty) {
              final response = await generateAIResponse(query);
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("AI Assistant Response"),
                  content: Text(response),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("OK"),
                    ),
                  ],
                ),
              );
            }
          },
          child: const Text("Ask"),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text("Close"),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget bodyContent;
    switch (_selectedIndex) {
      case 0:
        bodyContent = _buildDashboardPage();
        break;
      case 1:
        bodyContent = buildAnalyticsPage();
        break;
      case 2:
        bodyContent = buildFootprintPage();
        break;
      case 3:
        bodyContent = buildTipsPage();
        break;
      default:
        bodyContent = _buildDashboardPage();
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Climate Action'),
      ),
      body: bodyContent,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calculate),
            label: 'Footprint',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tips_and_updates),
            label: 'Tips',
          ),
        ],
      ),
      // Floating button to demo notifications.
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => buildAIQuestionDialog(),
          );
        },
        tooltip: "Ask AI Assistant",
        child: const Icon(Icons.chat),
      ),
    );
  }
}
