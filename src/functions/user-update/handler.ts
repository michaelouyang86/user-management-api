import type { APIGatewayProxyHandler } from "aws-lambda";
import {
    DynamoDBClient,
    UpdateItemCommand,
    ConditionalCheckFailedException,
    type AttributeValue
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

        const body = JSON.parse(event.body ?? "{}");

        const {
            first_name,
            last_name,
            email,
            image_keys
        } = body;

        if (
            first_name === undefined &&
            last_name === undefined &&
            email === undefined &&
            image_keys === undefined
        ) {
            return jsonResponse(400, { message: "At least one of first_name, last_name, email, image_keys must be provided" });
        }

        if (first_name !== undefined && (typeof first_name !== "string" || !first_name)) {
            return jsonResponse(400, { message: "first_name must be a non-empty string" });
        }
        if (last_name !== undefined && (typeof last_name !== "string" || !last_name)) {
            return jsonResponse(400, { message: "last_name must be a non-empty string" });
        }
        if (email !== undefined && (typeof email !== "string" || !email)) {
            return jsonResponse(400, { message: "email must be a non-empty string" });
        }
        if (
            image_keys !== undefined &&
            (!Array.isArray(image_keys) || image_keys.some((key: unknown) => typeof key !== "string"))
        ) {
            return jsonResponse(400, { message: "image_keys must be an array of strings" });
        }

        // Build the update expression dynamically so unsupplied fields are left untouched.
        const setClauses: string[] = [];
        const removeClauses: string[] = [];
        const names: Record<string, string> = {};
        const values: Record<string, AttributeValue> = {};

        if (first_name !== undefined) {
            setClauses.push("#first_name = :first_name");
            names["#first_name"] = "first_name";
            values[":first_name"] = { S: first_name };
        }
        if (last_name !== undefined) {
            setClauses.push("#last_name = :last_name");
            names["#last_name"] = "last_name";
            values[":last_name"] = { S: last_name };
        }
        if (email !== undefined) {
            setClauses.push("#email = :email");
            names["#email"] = "email";
            values[":email"] = { S: email };
        }
        if (image_keys !== undefined) {
            names["#image_keys"] = "image_keys";
            if (image_keys.length > 0) {
                setClauses.push("#image_keys = :image_keys");
                values[":image_keys"] = {
                    L: image_keys.map((key: string) => ({ S: key }))
                };
            } else {
                // Empty image_keys means "remove all images" - the attribute is omitted rather than stored empty.
                removeClauses.push("#image_keys");
            }
        }

        const updateExpression = [
            setClauses.length > 0 ? `SET ${setClauses.join(", ")}` : "",
            removeClauses.length > 0 ? `REMOVE ${removeClauses.join(", ")}` : ""
        ].filter(Boolean).join(" ");

        const result = await dynamodb.send(
            new UpdateItemCommand({
                TableName: TABLE_NAME,
                Key: {
                    user_id: { S: userId }
                },
                ConditionExpression: "attribute_exists(user_id)",
                UpdateExpression: updateExpression,
                ExpressionAttributeNames: names,
                ...(Object.keys(values).length > 0 && { ExpressionAttributeValues: values }),
                ReturnValues: "ALL_NEW"
            })
        );

        const item = result.Attributes;

        return jsonResponse(200, {
            user_id: item?.user_id?.S ?? "",
            first_name: item?.first_name?.S ?? "",
            last_name: item?.last_name?.S ?? "",
            email: item?.email?.S ?? "",
            image_keys: item?.image_keys?.L?.map((key) => key.S ?? "") ?? [],
            created_at: item?.created_at?.S ?? ""
        });

    } catch (error) {
        if (error instanceof ConditionalCheckFailedException) {
            return jsonResponse(404, { message: "User not found" });
        }

        console.error("Failed to update user:", error);

        return jsonResponse(500, { message: "Internal server error" });
    }
};
    