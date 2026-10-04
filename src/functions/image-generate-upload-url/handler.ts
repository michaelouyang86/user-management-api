import type { APIGatewayProxyHandler } from "aws-lambda";
import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
import { getSignedUrl } from "@aws-sdk/s3-request-presigner";
import { randomUUID } from "crypto";
import { jsonResponse } from "../../shared/response.js";

const BUCKET_NAME = process.env.BUCKET_NAME;

if (!BUCKET_NAME) {
    throw new Error("BUCKET_NAME environment variable is not set");
}

const s3 = new S3Client({});

export const handler: APIGatewayProxyHandler = async (event) => {
    try {
        const body = JSON.parse(event.body ?? "{}");

        const { content_type } = body;

        // Validate content type
        const allowedContentTypes = [
            "image/jpeg",
            "image/png",
            "image/webp"
        ];

        if (
            !content_type ||
            typeof content_type !== "string" ||
            !allowedContentTypes.includes(content_type)
        ) {
            return jsonResponse(400, { message: "Unsupported image content type" });
        }

        // Generate an independent image ID
        const imageId = randomUUID();

        // Map MIME type to file extension
        const extensionMap: Record<string, string> = {
            "image/jpeg": "jpg",
            "image/png": "png",
            "image/webp": "webp"
        };

        const extension = extensionMap[content_type];

        const imageKey = `users/images/${imageId}.${extension}`;

        // Create S3 PUT command
        const command = new PutObjectCommand({
            Bucket: BUCKET_NAME,
            Key: imageKey,
            ContentType: content_type
        });

        // Generate presigned URL
        const uploadUrl = await getSignedUrl(s3, command, {
            expiresIn: 300
        });

        return jsonResponse(201, {
            image_key: imageKey,
            upload_url: uploadUrl
        });

    } catch (error) {
        console.error("Failed to generate image upload URL:", error);

        return jsonResponse(500, { message: "Internal server error" });
    }
};
