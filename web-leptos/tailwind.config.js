/** @type {import('tailwindcss').Config} */
module.exports = {
    content: [
        "./src/**/*.{rs,html}", // Adjust if your HTML is in a different location
        "./index.html",
        "./node_modules/preline/dist/*.js", // If using Preline
    ],
    theme: {
        extend: {},
    },
    plugins: [
        require('preline/plugin'), // If using Preline
    ],
}