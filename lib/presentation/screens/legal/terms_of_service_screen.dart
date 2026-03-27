import 'package:flutter/material.dart';

/// Terms of Service placeholder screen
/// TODO: Replace with actual terms of service before production release
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade300),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Placeholder Content',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            
            // Title
            const Text(
              'Terms of Service',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 32),
            
            // Content
            const Text(
              'Our comprehensive terms of service are currently being finalized. '
              'These terms will govern your use of the Shoply application and services.',
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 24),
            
            const Text(
              'This document will cover:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            ..._buildBulletPoints([
              'Acceptance of terms',
              'User account responsibilities',
              'Acceptable use policy',
              'Intellectual property rights',
              'User-generated content guidelines',
              'Premium subscription terms',
              'Payment and billing policies',
              'Refund and cancellation policies',
              'Limitation of liability',
              'Dispute resolution procedures',
              'Modifications to terms',
              'Termination of service',
            ]),
            
            const SizedBox(height: 32),
            
            // Contact section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Questions?',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'If you have any questions about our terms, please contact us:',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 20, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'support@shoply.app',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Developer note
            Text(
              'Note: This is a placeholder. You must replace this with complete, legally compliant terms of service before releasing your app to production. '
              'Consult with a legal professional to ensure compliance with applicable laws.',
              style: TextStyle(
                fontSize: 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<Widget> _buildBulletPoints(List<String> points) {
    return points.map((point) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('• ', style: TextStyle(fontSize: 16)),
            Expanded(
              child: Text(
                point,
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}
