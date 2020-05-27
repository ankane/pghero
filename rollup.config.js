import buble from "@rollup/plugin-buble";
import commonjs from "@rollup/plugin-commonjs";
import resolve from "@rollup/plugin-node-resolve";

export default [
  {
    input: "src/index.js",
    output: {
      file: "app/assets/javascripts/pghero/application.js",
      format: "iife"
    },
    plugins: [
      resolve(),
      commonjs(),
      buble()
    ]
  }
];
