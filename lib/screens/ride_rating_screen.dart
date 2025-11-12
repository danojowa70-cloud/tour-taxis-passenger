import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/socket_ride_providers.dart';
import '../models/ride.dart';

class RideRatingScreen extends ConsumerStatefulWidget {
  final Ride ride;
  
  const RideRatingScreen({super.key, required this.ride});

  @override
  ConsumerState<RideRatingScreen> createState() => _RideRatingScreenState();
}

class _RideRatingScreenState extends ConsumerState<RideRatingScreen> {
  int _rating = 0;
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a rating'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref.read(socketRideProvider.notifier).rateDriver(
        rating: _rating,
        feedback: _feedbackController.text.trim().isNotEmpty 
            ? _feedbackController.text.trim() 
            : null,
      );

      if (mounted) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: Colors.green,
          ),
        );

        // Wait a moment then go home
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          // Reset ride state and go home
          ref.read(socketRideProvider.notifier).reset();
          Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
        }
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _skipRating() {
    ref.read(socketRideProvider.notifier).reset();
    Navigator.of(context).pushNamedAndRemoveUntil('/home', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              
              // Success icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle,
                  size: 60,
                  color: Colors.green,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Trip Completed!',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: 12),
              
              Text(
                'Rate your experience',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Trip summary card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    // Driver info
                    Row(
                      children: [
                        // Driver avatar
                        CircleAvatar(
                          radius: 30,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                          child: widget.ride.driverImage != null
                              ? ClipOval(
                                  child: Image.network(
                                    widget.ride.driverImage!,
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.person,
                                      size: 30,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                )
                              : Icon(
                                  Icons.person,
                                  size: 30,
                                  color: theme.colorScheme.primary,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.ride.driverName ?? 'Driver',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.ride.driverVehicle ?? 'Vehicle',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              if (widget.ride.driverVehicleNumber != null)
                                Text(
                                  widget.ride.driverVehicleNumber!,
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 20),
                    
                    // Trip details
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildDetailItem(
                          context,
                          Icons.route,
                          widget.ride.distance ?? '—',
                          'Distance',
                        ),
                        _buildDetailItem(
                          context,
                          Icons.access_time,
                          widget.ride.duration ?? '—',
                          'Duration',
                        ),
                        _buildDetailItem(
                          context,
                          Icons.attach_money,
                          widget.ride.fare ?? '—',
                          'Fare',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Rating stars
              Text(
                'How was your ride?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              
              const SizedBox(height: 16),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final starValue = index + 1;
                  return GestureDetector(
                    onTap: () => setState(() => _rating = starValue),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Icon(
                        _rating >= starValue ? Icons.star : Icons.star_border,
                        size: 48,
                        color: _rating >= starValue
                            ? Colors.amber
                            : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  );
                }),
              ),
              
              if (_rating > 0) ...[
                const SizedBox(height: 8),
                Text(
                  _getRatingText(_rating),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              
              const SizedBox(height: 32),
              
              // Feedback text field
              TextField(
                controller: _feedbackController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Share your experience (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surface,
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitRating,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Submit Rating',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Skip button
              TextButton(
                onPressed: _isSubmitting ? null : _skipRating,
                child: Text(
                  'Skip for now',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, IconData icon, String value, String label) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(
          icon,
          color: theme.colorScheme.primary,
          size: 24,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
}
