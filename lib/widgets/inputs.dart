import 'package:flutter/material.dart';

class AppleTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;
  final bool obscureText;
  final TextInputAction textInputAction;
  final void Function(String)? onSubmitted;

  const AppleTextField({super.key, required this.controller, required this.hintText, this.keyboardType = TextInputType.text, this.obscureText = false, this.textInputAction = TextInputAction.next, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      textInputAction: textInputAction,
      decoration: InputDecoration(
        hintText: hintText,
      ),
    );
  }
}

class AppleButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isPrimary;

  const AppleButton({super.key, required this.label, required this.onPressed, this.isPrimary = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: isPrimary
          ? ElevatedButton(
              onPressed: onPressed,
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(label),
            ),
    );
  }
}


