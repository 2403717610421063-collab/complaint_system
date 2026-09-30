enum EeQuickFilter {
  none,
  approvalsQueue,
  escalated,
  slaBreached,
  paymentPending,
  resolved,
}

class EeComplaintsIntent {
  final EeQuickFilter filter;

  const EeComplaintsIntent(this.filter);
}
