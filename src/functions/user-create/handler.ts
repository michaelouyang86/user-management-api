import type { APIGatewayProxyHandler } from "aws-lambda";
import { DynamoDBClient, PutItemCommand } from "@aws-sdk/client-dynamodb";
import { randomUUID } from "crypto";
import { jsonResponse } from "../../shared/response.js";

const TABLE_NAME = process.env.TABLE_NAME;

if (!TABLE_NAME) {
    throw new Error("TABLE_NAME environment variable is not set");
}

const dynamodb = new DynamoDBClient({});

export const handler: APIGatewayProxyHandler = async (event) => {
    try {
        const body = JSON.parse(event.body ?? "{}");

        const {
            first_name,
            last_name,
            email,
            image_keys = []
        } = body;

        // Basic validation
        if (!first_name || !last_name || !email) {
            return jsonResponse(400, { message: "first_name, last_name and email are required" });
        }

        // Generate values on the backend
        const userId = randomUUID();
        const createdAt = new Date().toISOString();

        const item = {
            user_id: {
                S: userId
            },
            first_name: {
                S: first_name
            },
            last_name: {
                S: last_name
            },
            email: {
                S: email
            },
            ...(image_keys.length > 0 && {
                image_keys: {
                    L: image_keys.map((key: string) => ({ S: key }))
                }
            }),
            created_at: {
                S: createdAt
            }
        };

        await dynamodb.send(
            new PutItemCommand({
                TableName: TABLE_NAME,
                Item: item
            })
        );

        return jsonResponse(201, {
            user_id: userId,
            first_name,
            last_name,
            email,
            image_keys,
            created_at: createdAt
        });

    } catch (error) {
        console.error("Failed to create user:", error);

        return jsonResponse(500, { message: "Internal server error" });
    }
};