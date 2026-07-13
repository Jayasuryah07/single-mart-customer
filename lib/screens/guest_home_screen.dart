import 'package:flutter/material.dart';

class GuestHomeScreen extends StatelessWidget {
  const GuestHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate-tinged off-white
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'SingleMart',
          style: TextStyle(
            color: Color(0xFF1E1B4B),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.logout_rounded, color: Color(0xFF64748B)),
          onPressed: () {
            // Logout of guest mode, return to login
            Navigator.of(context).pop();
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Welcome Graphic
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.account_circle_outlined,
                    size: 64,
                    color: Color(0xFF6C63FF),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              
              // Welcome text
              const Text(
                'Welcome, Guest!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'You are currently browsing SingleMart in Guest Mode. Sign in or register to purchase items or list your products.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              
              // Call to Action card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: Color(0xFF6C63FF)),
                        SizedBox(width: 12),
                        Text(
                          'Limited Permissions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'As a guest, you can explore the marketplace catalogs but cannot process checkouts or store dashboards.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF475569),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Exit Guest Mode button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Exit Guest Mode',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
