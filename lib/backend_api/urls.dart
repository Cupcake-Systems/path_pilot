import '../app_storage.dart';

//const protocol = "https";
const protocol = "http";
//const domain = "path_pilot.cupcake-systems.com";
const domain = "127.0.0.1:8000";
final userId = PreservingStorage.userId;

const submitLogPath = "/logs/submit";
const submitLogUrl = "$protocol://$domain$submitLogPath";

final identificationHeader = {
  "Authorization": "Bearer ${userId.toString()}",
};