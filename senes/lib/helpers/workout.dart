import 'package:senes/helpers/route_point.dart';
import 'package:senes/helpers/openweather_wrapper.dart';
import 'package:uuid/uuid.dart';

class Workout {
  DateTime startTime;
  DateTime endTime;
  Weather weather;
  List<RoutePoint> route;

  late Duration duration;
  late final String workoutID;

  Workout(this.startTime, this.endTime, this.weather, this.route) {
    workoutID = const Uuid().v4();
    duration = Duration(
        milliseconds:
            endTime.millisecondsSinceEpoch - startTime.millisecondsSinceEpoch);
  }
}