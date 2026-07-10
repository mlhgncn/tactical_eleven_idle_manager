import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

class AsyncStateBuilder extends StatelessWidget {
  final bool isLoading;
  final String? errorMessage;
  final bool isEmpty;
  final Widget Function()? emptyBuilder;
  final Widget child;

  const AsyncStateBuilder({super.key, required this.isLoading, this.errorMessage, this.isEmpty = false, this.emptyBuilder, required this.child});

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null && errorMessage!.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text(errorMessage!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    if (isEmpty) {
      return emptyBuilder != null
          ? emptyBuilder!()
          : Center(child: Text('common.noDataYet'.tr()));
    }

    return child;
  }
}
