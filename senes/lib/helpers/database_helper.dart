import 'package:latlong2/latlong.dart';
import 'package:senes/helpers/future_workout.dart';
import 'package:senes/helpers/openweather_wrapper.dart';
import 'package:senes/helpers/route_point.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';

import 'workout.dart';

class DBHelper {
  DBHelper._privateConstructor();

  static DBHelper dbHelper = DBHelper._privateConstructor();

  late Database _database;

  Future<Database> get database async {
    _database = await _createDatabase();

    return _database;
  }

  //Creates database object
  Future<Database> _createDatabase() async {
    return await openDatabase(join(await getDatabasesPath(), 'senes.db'),
        onCreate: (Database db, int version) {
      for (String table in _createDatabaseSQL) {
        db.execute(table);
      }
    }, version: 1);
  }

  // Deletes database
  void _deleteDatabase() async {
    deleteDatabase(join(await getDatabasesPath(), 'senes.db'));
  }

  void insertFuture(FutureWorkout data) async {
    /// Inserts a new Scheduled workout into the database
    ///
    /// Parameters:
    /// FutureWorkout data  -   data for scheduled workout

    //Connect to db
    Database db = await _createDatabase();

    // Insert into db
    await db.insert('futureworkout', {
      'workoutid': data.id,
      'time': data.time,
      'goal': data.goal.inMilliseconds,
      'route': data.route,
    });

    //cleanup
    await db.close();
  }

  Future<FutureWorkout?> getFuture(String id) async {
    /// Retrieve scheduled workout from database
    ///
    /// Parameters:
    /// String id   -   id of scheduled workout

    //Connect to db
    Database db = await _createDatabase();

    List<Map<String, dynamic>> data = await db
        .query('futureworkout', where: "workoutid = ?", whereArgs: [id]);

    if (data.isNotEmpty) {
      return FutureWorkout(data[0]['time']);
    } else {
      return null;
    }
  }

  void insertWorkout(Workout data) async {
    /// insertWorkout(Workout data)
    /// Inserts the given workout into the database
    /// All info stored by workout object is put into appropriate database tables

    //Connect to db
    Database db = await _createDatabase();

    //Things to go into weather table
    String wid = data.weather.weatherid;
    double temp = data.weather.temp!;
    String clouds = data.weather.clouds!;
    double windSpeed = data.weather.wind!["speed"];
    int windDir = data.weather.wind!['deg'];
    int pressure = data.weather.pressure!;
    int humidity = data.weather.humidity!;

    await db.insert('weather', {
      'weatherid': wid,
      'clouds': clouds,
      'pressure': pressure,
      'humidity': humidity,
      'wind_speed': windSpeed,
      'wind_direction': windDir,
      'temperature': temp,
    });

    String rid = const Uuid().v4();

    //Things to go into points table
    for (RoutePoint point in data.route) {
      String pid = const Uuid().v4();
      double latitude = point.latlng.latitude;
      double longitude = point.latlng.longitude;
      double altitude = point.altitude;
      int time = point.time.millisecondsSinceEpoch;

      await db.insert('points', {
        'pointid': pid,
        'routeid': rid,
        'latitude': latitude,
        'longitude': longitude,
        'altitude': altitude,
        'time': time
      });
    }

    //Things to go into workout table
    String id = data.workoutID;
    int start = data.startTime.millisecondsSinceEpoch;
    int end = data.endTime.millisecondsSinceEpoch;
    int duration = data.duration.inMilliseconds;

    await db.insert('pastworkout', {
      'workoutid': id,
      'start': start,
      'end': end,
      'duration': duration,
      'weather': wid,
      'route': rid
    });

    await db.close();
  }

  Future<Workout?> getWorkout(String id) async {
    ///getWorkout(String id)
    ///Fetches workout with specified id from database
    ///returns Future for Workout object
    Database db = await _createDatabase();

    //get data from workout table
    Map<String, dynamic> data = (await db
        .query("pastworkout", where: 'workoutid = ?', whereArgs: [id]))[0];

    // successfully found data
    if (data.isNotEmpty) {
      // get data for Weather object
      Map<String, dynamic> weatherData = (await db.query('weather',
          where: 'weatherid = ?', whereArgs: [data['weather']]))[0];

      //Construct weather object
      Weather weather = Weather(
          weatherData['temperature'],
          weatherData['clouds'],
          weatherData['pressure'],
          weatherData['humidity'],
          {'speed': weatherData['wind_speed'], 'deg': weatherData['deg']});

      // get data for route
      List<Map<String, dynamic>> routeData = await db
          .query('points', where: 'routeid = ?', whereArgs: [data['route']]);

      //close db
      await db.close();

      //Generate list of points
      List<RoutePoint> points = List.generate(routeData.length, (int i) {
        return RoutePoint.withTime(
            LatLng(routeData[i]['latitude'], routeData[i]['longitude']),
            routeData[i]['altitude'].toDouble(),
            DateTime.fromMillisecondsSinceEpoch(routeData[0]['time']));
      });

      // Construct workout object
      Workout workout = Workout(
          DateTime(data['start']), DateTime(data['end']), weather, points);

      return workout;
    } else {
      return null;
    }
  }

  final List<String> _createDatabaseSQL = [
    """
CREATE TABLE "user" (
	"userid"	TEXT NOT NULL,
	"name"	TEXT NOT NULL,
	"age"	INTEGER NOT NULL,
	PRIMARY KEY("userid")
);""",
    """CREATE TABLE "futureworkout" (
	"workoutid"	TEXT NOT NULL,
	"time"	INTEGER NOT NULL,
  "goal"  INTEGER NOT NULL,
  "notes" STRING NOT NULL,
	"route"	INTEGER,
	FOREIGN KEY("route") REFERENCES "route"("routeid"),
	PRIMARY KEY("workoutid")
);""",
    """CREATE TABLE "pastworkout" (
	"workoutid"	TEXT NOT NULL,
	"start"	INTEGER NOT NULL,
	"end"	INTEGER NOT NULL,
	"duration"	INTEGER NOT NULL,
	"weather"	TEXT NOT NULL,
	"route"	TEXT NOT NULL,
	FOREIGN KEY("route") REFERENCES "points"("routeid"),
	FOREIGN KEY("weather") REFERENCES "weather"("weatherid"),
	PRIMARY KEY("workoutid")
);""",
    """CREATE TABLE "points" (
	"pointid"	TEXT NOT NULL,
	"routeid"	TEXT NOT NULL,
	"latitude"	NUMERIC NOT NULL,
	"longitude"	NUMERIC NOT NULL,
	"time"	INTEGER NOT NULL,
	"altitude"	NUMERIC NOT NULL
);""",
    """CREATE TABLE "weather" (
	"weatherid"	TEXT NOT NULL,
	"clouds"	TEXT NOT NULL,
	"pressure"	INTEGER NOT NULL,
	"humidity"	INTEGER NOT NULL,
	"wind_speed"	NUMERIC NOT NULL,
	"wind_direction"	INTEGER NOT NULL,
	"temperature"	NUMERIC NOT NULL,
	PRIMARY KEY("weatherid")
);"""
  ];
}