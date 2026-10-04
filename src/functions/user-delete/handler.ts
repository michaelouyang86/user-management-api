import type { APIGatewayProxyHandler } from "aws-lambda";
import {
    DynamoDBClient,
    DeleteItemCommand,
    ConditionalCheckFailedException
} from "@aws-sdk/client-dynamodb";
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

        await dynamodb.send(
            new DeleteItemCommand({
                TableName: TABLE_NAME,
                Key: {
                    user_id: { S: userId }
                },
                ConditionExpression: "attribute_exists(user_id)"
            })
        );

        return jsonResponse(204, {});

    } catch (error) {
        if (error instanceof ConditionalCheckFailedException) {
            return jsonResponse(404, { message: "User not found" });
        }

        console.error("Failed to delete user:", error);

        return jsonResponse(500, { message: "Internal server error" });
    }
};
