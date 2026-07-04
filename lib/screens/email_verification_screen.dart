import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class EmailVerificationScreen extends StatelessWidget {
  const EmailVerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('E-posta Doğrulama'.tr()),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Kaydınız alındı. Lütfen e-posta adresinize gönderilen doğrulama bağlantısını tıklayarak hesabınızı aktifleştirin.'.tr(),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text(
              'Doğrulama tamamlandıktan sonra tekrar giriş yapabilirsiniz.'.tr(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pushReplacementNamed('/auth');
              },
              child: Text('Giriş Ekranına Dön'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
