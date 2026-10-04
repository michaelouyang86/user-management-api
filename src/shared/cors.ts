const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN;

if (!ALLOWED_ORIGIN) {
    throw new Error("ALLOWED_ORIGIN environment variable is not set");
}

export const corsHeaders = {
    "Access-Control-Allow-Origin": ALLOWED_ORIGIN,
    "Access-Control-Allow-Methods": "GET,POST,PUT,DELETE",
    "Access-Control-Allow-Headers": "Content-Type"
};