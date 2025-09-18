/// A simple log function that uses print.
void log(Object? object) {
  // NOTE(jeroen-meijer): Use print to avoid the need for a logger dependency.
  // ignore: avoid_print
  print(object);
}
