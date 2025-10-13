class MPesaService {
  Future<String> initiateStkPush({required String phone, required double amount}) async {
    // TODO: Call backend to initiate M-Pesa STK Push; return checkoutRequestID
    await Future.delayed(const Duration(milliseconds: 300));
    return 'mpesa_checkout_request_id_placeholder';
  }

  Future<String> checkPaymentStatus(String checkoutRequestId) async {
    // TODO: Poll backend for M-Pesa result
    await Future.delayed(const Duration(milliseconds: 300));
    return 'SUCCESS';
  }
}


