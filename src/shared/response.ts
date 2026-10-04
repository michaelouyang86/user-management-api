import { corsHeaders } from "./cors.js";

export function jsonResponse(
    statusCode: number,
    body: unknown
) {
    return {
        statusCode,
        headers: {
            "Content-Type": "application/json",
            ...corsHeaders
        },
        body: JSON.stringify(body)
    };
}