class GuvenlikServisi {
  static final GuvenlikServisi _instance = GuvenlikServisi._internal();
  factory GuvenlikServisi() => _instance;
  GuvenlikServisi._internal();

  bool sahteMod = false; // Uygulama açıldığında varsayılan olarak kapalıdır
}