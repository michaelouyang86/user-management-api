import fs from "fs";
import { build } from "esbuild";

const functions = [
    "user-get",
    "user-get-by-id",
    "user-create",
    "user-update",
    "user-delete",
    "image-generate-download-url",
    "image-generate-upload-url"
];

// src/functions/user-create/handler.ts -> dist/functions/user-create/index.js
for (const functionName of functions) {
    const source = `src/functions/${functionName}/handler.ts`;
    const outputDir = `dist/functions/${functionName}`;

    fs.mkdirSync(outputDir, { recursive: true });

    await build({
        entryPoints: [source],
        bundle: true,
        platform: "node",
        target: "node22",
        format: "cjs",
        outfile: `${outputDir}/index.js`,
        sourcemap: false
    });

    console.log(`Built ${functionName}`);
}