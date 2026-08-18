const surface = import.meta.env.VITE_FANATICAL_SURFACE;

if (surface === "admin") {
  void import("./admin/main");
} else {
  void import("./main");
}
