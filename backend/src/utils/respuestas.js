export function responder(res, data, status = 200) {
  return res.status(status).json({ success: true, data });
}

export function responderError(res, error) {
  const body = {
    success: false,
    error: {
      code: error.code,
      message: error.message,
    },
  };

  if (error.details) body.error.details = error.details;
  return res.status(error.status).json(body);
}