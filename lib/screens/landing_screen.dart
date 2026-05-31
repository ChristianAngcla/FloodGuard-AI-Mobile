// import 'package:flutter/material.dart';
// import '../widgets/app_drawer.dart';

// class LandingPage extends StatefulWidget {
//   const LandingPage({super.key});

//   @override
//   State<LandingPage> createState() => _LandingPageState();
// }

// class _LandingPageState extends State<LandingPage> {
//   bool _isDarkMode = false;
//   bool _isTaglish = false;

//   String t(String key) {
//     return key;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFCAE1FC),

//       // 👉 RIGHT DRAWER
//       endDrawer: AppDrawer(
//         isDarkMode: _isDarkMode,
//         isTaglish: _isTaglish,
//         onToggleDarkMode: setDarkMode,
//         onToggleLanguage: setLanguage,
//       ),

//       body: Stack(
//         children: [
//           // 🌍 MAP BACKGROUND (placeholder)
//           Container(
//             decoration: const BoxDecoration(
//               gradient: LinearGradient(
//                 colors: [
//                   Color(0xFF3784DF),
//                   Color(0xFFCAE1FC),
//                 ],
//                 begin: Alignment.topCenter,
//                 end: Alignment.bottomCenter,
//               ),
//             ),
//           ),

//           // 🍔 MENU BUTTON
//           Positioned(
//             top: 40,
//             right: 20,
//             child: Builder(
//               builder: (context) => FloatingActionButton(
//                 mini: true,
//                 backgroundColor: Colors.white,
//                 elevation: 4,
//                 onPressed: () {
//                   Scaffold.of(context).openEndDrawer();
//                 },
//                 child: const Icon(
//                   Icons.menu,
//                   color: Color(0xFF3784DF),
//                 ),
//               ),
//             ),
//           ),

//           // 🪟 POPUP CONTENT
//           Center(
//             child: Container(
//               width: MediaQuery.of(context).size.width * 0.88,
//               padding: const EdgeInsets.all(20),
//               decoration: BoxDecoration(
//                 color: Colors.white.withOpacity(0.96),
//                 borderRadius: BorderRadius.circular(24),
//                 boxShadow: const [
//                   BoxShadow(color: Colors.black26, blurRadius: 14),
//                 ],
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // 🌊 ASSET ICON + TITLE
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.center,
//                     children: [
//                       Image.asset(
//                         'assets/icons/app_icon.png',
//                         width: 36,
//                         height: 36,
//                       ),
//                       const SizedBox(width: 10),
//                       const Text(
//                         "FloodGuard AI",
//                         style: TextStyle(
//                           fontSize: 22,
//                           fontWeight: FontWeight.bold,
//                           color: Color(0xFF3784DF),
//                         ),
//                       ),
//                     ],
//                   ),

//                   const SizedBox(height: 16),

//                   // 📝 DESCRIPTION
//                   const Text(
//                     "The system forecasts and visualizes flood hazards in Marikina by using machine learning to assess probabilities based on elevation, drainage, rainfall, and historical flood data, displaying a color-coded risk map (Low, Moderate, High) that supports the Preparedness and Mitigation phases of disaster management.",
//                     textAlign: TextAlign.center,
//                     style: TextStyle(
//                       fontSize: 14,
//                       color: Color(0xFF4A5A6A),
//                     ),
//                   ),

//                   const SizedBox(height: 20),

//                   // 🔍 SEARCH LOCATION
//                   TextField(
//                     decoration: InputDecoration(
//                       hintText: "Search location",
//                       prefixIcon: const Icon(Icons.search),
//                       suffixIcon: const Icon(Icons.my_location),
//                       filled: true,
//                       fillColor: const Color(0xFFF2F6FB),
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(14),
//                         borderSide: BorderSide.none,
//                       ),
//                     ),
//                   ),

//                   const SizedBox(height: 20),

//                   // 🗺️ MAP BUTTONS WITH ASSET ICONS
//                   Row(
//                     children: [
//                       Expanded(
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: const Color(0xFF3784DF),
//                             padding: const EdgeInsets.symmetric(vertical: 14),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(16),
//                             ),
//                           ),
//                           onPressed: () {},
//                           child: Column(
//                             children: [
//                               Image.asset(
//                                 'assets/icons/flood_map.png',
//                                 width: 32,
//                                 height: 32,
//                                 color: Colors.white,
//                               ),
//                               const SizedBox(height: 6),
//                               const Text("Flood Map"),
//                             ],
//                           ),
//                         ),
//                       ),
//                       const SizedBox(width: 12),
//                       Expanded(
//                         child: ElevatedButton(
//                           style: ElevatedButton.styleFrom(
//                             backgroundColor: const Color(0xFF9FAEBE),
//                             padding: const EdgeInsets.symmetric(vertical: 14),
//                             shape: RoundedRectangleBorder(
//                               borderRadius: BorderRadius.circular(16),
//                             ),
//                           ),
//                           onPressed: () {},
//                           child: Column(
//                             children: [
//                               Image.asset(
//                                 'assets/icons/weather_map.png',
//                                 width: 32,
//                                 height: 32,
//                                 color: Colors.white,
//                               ),
//                               const SizedBox(height: 6),
//                               const Text("Weather Map"),
//                             ],
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
