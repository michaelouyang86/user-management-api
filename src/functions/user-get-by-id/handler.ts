import type { APIGatewayProxyHandler } from "aws-lambda";
import { DynamoDBClient, GetItemCommand } from "@aws-sdk/client-dynamodb";
import { jsonResponse } from "../../shared/response.js";

const TABLE_NAME = process.env.TABLE_NAME;

if (!TABLE_NAME) {
    throw new Error("TABLE_NAME environment variable is not set");
}

const dynamodb = new DynamoDBClient({});

export const handler: APIGatewayProxyHandler = async (event) => {
    try {
        const userId = event.pathParameters?.userId;

        if (!userId) {
            return jsonResponse(400, { message: "userId is required" });
        }

        const result = await dynamodb.send(
            new GetItemCommand({
                TableName: TABLE_NAME,
                Key: {
                    user_id: { S: userId }
                }
            })
        );

        if (!result.Item) {
            return jsonResponse(404, { message: "User not found" });
        }

        const item = result.Item;

        return jsonResponse(200, {
            user_id: item.user_id?.S ?? "",
            first_name: item.first_name?.S ?? "",
            last_name: item.last_name?.S ?? "",
            email: item.email?.S ?? "",
            image_keys: item.image_keys?.L?.map((key) => key.S ?? "") ?? [],
            created_at: item.created_at?.S ?? ""
        });

    } catch (error) {
        console.error("Failed to get user:", error);

        return jsonResponse(500, { message: "Internal server error" });
    }
};
