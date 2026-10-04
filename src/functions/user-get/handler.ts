import type { APIGatewayProxyHandler } from "aws-lambda";
import { DynamoDBClient, ScanCommand } from "@aws-sdk/client-dynamodb";
import { jsonResponse } from "../../shared/response.js";

const TABLE_NAME = process.env.TABLE_NAME;

if (!TABLE_NAME) {
    throw new Error("TABLE_NAME environment variable is not set");
}

const dynamodb = new DynamoDBClient({});

export const handler: APIGatewayProxyHandler = async () => {
    try {
        const result = await dynamodb.send(
            new ScanCommand({
                TableName: TABLE_NAME
            })
        );

        const users = (result.Items ?? []).map((item) => ({
            user_id: item.user_id?.S ?? "",
            first_name: item.first_name?.S ?? "",
            last_name: item.last_name?.S ?? "",
            email: item.email?.S ?? "",
            image_keys: item.image_keys?.L?.map((key) => key.S ?? "") ?? [],
            created_at: item.created_at?.S ?? ""
        }));

        return jsonResponse(200, { users });

    } catch (error) {
        console.error("Failed to list users:", error);

        return jsonResponse(500, { message: "Internal server error" });
    }
};
