import fs from "fs";
import { ZipArchive } from "archiver";

const functions = [
    "user-get",
    "user-get-by-id",
    "user-create",
    "user-update",
    "user-delete",
    "image-generate-download-url",
    "image-generate-upload-url"
];

// dist/functions/user-create/index.js -> dist/user-create.zip
for (const functionName of functions) {
    const sourceFile = `dist/functions/${functionName}/index.js`;
    const outputPath = `dist/${functionName}.zip`;

    await createZip(sourceFile, outputPath);

    console.log(`Created ${outputPath}`);
}

function createZip(sourceFile, outputPath) {
    return new Promise((resolve, reject) => {
        const output = fs.createWriteStream(outputPath);
        const archive = new ZipArchive();

        output.on("close", resolve);
        archive.on("error", reject);

        archive.pipe(output);

        archive.file(sourceFile, {
            name: "index.js"
        });

        archive.finalize();
    });
}