import type { APIGatewayProxyHandler } from "aws-lambda";
import { S3Client, GetObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { jsonResponse } from "../../shared/response.js";

const BUCKET_NAME = process.env.BUCKET_NAME;

if (!BUCKET_NAME) {
    throw new Error("BUCKET_NAME environment variable is not set");
}

const s3 = new S3Client({});

export const handler: APIGatewayProxyHandler = async (event) => {
    try {
        const imageKey = event.queryStringParameters?.key;

        if (!imageKey || typeof imageKey !== "string") {
            return jsonResponse(400, { message: "key is required" });
        }

        // Create S3 GET command
        const command = new GetObjectCommand({
            Bucket: BUCKET_NAME,
            Key: imageKey
        });

        // Generate presigned URL
        const downloadUrl = await getSignedUrl(s3, command, {
            expiresIn: 300
        });

        return jsonResponse(200, {
            image_key: imageKey,
            download_url: downloadUrl
        });

    } catch (error) {
        console.error("Failed to generate image download URL:", error);

        return jsonResponse(500, { message: "Internal server error" });
    }
};
