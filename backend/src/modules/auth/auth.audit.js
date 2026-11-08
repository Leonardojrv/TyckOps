export class AuthAuditLogger {
  log(event) {
    console.info(JSON.stringify({
      type: 'auth_access',
      timestamp: new Date().toISOString(),
      ...event,
    }));
  }
}