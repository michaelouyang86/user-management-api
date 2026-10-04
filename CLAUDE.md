# User Management API

Serverless REST API for managing users on AWS.

## Source of truth

Each fact lives in exactly one place. Read the relevant file before writing code and do not restate its contents elsewhere.

| Topic | File |
|---|---|
| Endpoints, request/response bodies, status codes | `openapi.yaml` |
| AWS resources, naming, IAM, env vars, endpoint → Lambda mapping | `docs/infrastructure.md` |
| Tech stack, directory layout, coding rules | `CLAUDE.md` (this file) |

## Tech stack

* **Language:** TypeScript (`strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`, `verbatimModuleSyntax`)
* **Runtime:** AWS Lambda, Node.js
* **AWS SDK:** JavaScript v3 — `@aws-sdk/client-dynamodb`, `@aws-sdk/client-s3`, `@aws-sdk/s3-request-presigner`
* **Types:** `@types/aws-lambda`, `@types/node`
* **Bundler:** esbuild (one CommonJS bundle per function)
* **Packaging:** archiver (one zip per function)
* **Infrastructure as code:** Terraform
* **CI/CD:** GitHub Actions (not set up yet)

Do not add frameworks (Express, Middy, Serverless Framework, CDK, etc.) or new dependencies unless there is no reasonable alternative.

## Directory structure

```text
.
├── CLAUDE.md
├── openapi.yaml                  # API spec; also imported by Terraform as the API Gateway body
├── package.json                  # "type": "module"; scripts: build, package, clean
├── tsconfig.json
├── docs/
│   ├── infrastructure.md         # AWS infrastructure spec
│   └── testing.md
├── scripts/
│   ├── build.js                  # src/functions/<fn>/handler.ts -> dist/functions/<fn>/index.js
│   └── package.js                # dist/functions/<fn>/index.js  -> dist/<fn>.zip
├── src/
│   ├── shared/
│   │   ├── cors.ts               # CORS headers built from ALLOWED_ORIGIN
│   │   └── response.ts           # jsonResponse(statusCode, body)
│   └── functions/
│       └── <function-name>/
│           └── handler.ts        # exports `handler`
├── dist/                         # build output (generated, do not edit)
└── terraform/
    ├── main.tf                   # terraform/provider config, iam module wiring
    ├── variables.tf
    ├── terraform.tfvars
    ├── data.tf
    ├── api-gateway.tf
    ├── lambda.tf
    ├── dynamodb.tf
    ├── s3.tf
    └── iam/                      # module: one iam-<function-name>.tf per function
        ├── variables.tf
        ├── outputs.tf
        ├── data.tf
        └── iam-<function-name>.tf
```

Commands:

```bash
npm run build      # bundle all functions
npm run package    # zip all functions into dist/
npm run clean      # remove dist/
```

### Adding a new function

1. Add the operation to `openapi.yaml`.
2. Create `src/functions/<function-name>/handler.ts`.
3. Add `<function-name>` to the `functions` array in **both** `scripts/build.js` and `scripts/package.js`.
4. Add the infrastructure as described in `docs/infrastructure.md`.

## Coding rules

Use `src/functions/user-create/handler.ts` as the reference implementation and match its style.

### Handler structure

```typescript
import type { APIGatewayProxyHandler } from "aws-lambda";
import { DynamoDBClient, PutItemCommand } from "@aws-sdk/client-dynamodb";
import { jsonResponse } from "../../shared/response.js";

const TABLE_NAME = process.env.TABLE_NAME;

if (!TABLE_NAME) {
    throw new Error("TABLE_NAME environment variable is not set");
}

const dynamodb = new DynamoDBClient({});

export const handler: APIGatewayProxyHandler = async (event) => {
    try {
        // 1. Validate input -> return jsonResponse(400, { message: "..." })
        // 2. Call AWS
        // 3. Return jsonResponse(2xx, body) shaped exactly as in openapi.yaml
    } catch (error) {
        // Expected errors (e.g. ConditionalCheckFailedException -> 404) first
        console.error("Failed to <action>:", error);
        return jsonResponse(500, { message: "Internal server error" });
    }
};
```

Rules:

* One handler per function, exported as `handler`, typed as `APIGatewayProxyHandler`.
* Read env vars at module top level and throw if missing. Use only the env var names defined in `docs/infrastructure.md`.
* Create AWS clients once at module top level with an empty config (`new DynamoDBClient({})`, `new S3Client({})`); region and credentials come from the Lambda environment.
* Always build responses with `jsonResponse()` from `src/shared/response.ts`; it adds `Content-Type: application/json` and the CORS headers. Never build response objects by hand.
* Error bodies are always `{ "message": "..." }`.
* Never return AWS error messages or stack traces to the client. Log unexpected errors with `console.error("Failed to <action>:", error)` and return a generic 500.
* Use relative imports with the `.js` extension (`../../shared/response.js`) and `import type` for type-only imports.
* Use Node's built-in `randomUUID` from `crypto` for IDs; no `uuid` package.
* Use `async/await`; no callbacks or `.then()` chains.
* Avoid `any`; use `unknown` and narrow, or SDK types such as `AttributeValue`.
* 4-space indentation, double quotes, semicolons.
* Keep comments short and only where the intent is not obvious.

### DynamoDB

* Use the low-level client (`@aws-sdk/client-dynamodb`) with explicit attribute values (`{ S: ... }`, `{ L: [...] }`). Do not use `@aws-sdk/lib-dynamodb` or `marshall`/`unmarshall`.
* Item attributes use the same snake_case names as the `User` schema in `openapi.yaml`; all scalars are stored as `S`.
* `user_id` and `created_at` (ISO 8601 via `new Date().toISOString()`) are generated by the backend.
* `image_keys` is stored as an `L` of `S`. Omit the attribute when the list is empty, and `REMOVE` it on update when set to `[]`. Always return `image_keys: []` to the client when it is missing.
* For operations on an existing item (update, delete) use `ConditionExpression: "attribute_exists(user_id)"` and map `ConditionalCheckFailedException` to 404.

### S3 images

* Clients never upload or download through Lambda; handlers return presigned URLs (`getSignedUrl`, `expiresIn: 300`).
* Object key format: `users/images/{image_id}.{ext}`, where `image_id` is a new UUID that is independent of `user_id` and `ext` is derived from the content type.

### Changing existing code

* Do not modify `src/shared/*` or existing handlers unless required for the task or for consistency.
* When requirements are ambiguous, make the smallest reasonable assumption, document it in a code comment, and do not change the architecture.
