import { FileBlob, SpreadsheetFile } from "@oai/artifact-tool";

const inputPath = "D:/project-l/output/BaseInRunUpgradeDraft_CN.xlsx";
const input = await FileBlob.load(inputPath);
const workbook = await SpreadsheetFile.importXlsx(input);

const sheets = await workbook.inspect({
  kind: "sheet",
  include: "id,name",
  maxChars: 4000,
});
console.log(sheets.ndjson);

for (const range of ["基地等级!A1:K20", "小兵路线!A1:K20"]) {
  const table = await workbook.inspect({
    kind: "table",
    range,
    include: "values",
    tableMaxRows: 20,
    tableMaxCols: 11,
    tableMaxCellChars: 220,
    maxChars: 12000,
  });
  console.log(table.ndjson);
}
