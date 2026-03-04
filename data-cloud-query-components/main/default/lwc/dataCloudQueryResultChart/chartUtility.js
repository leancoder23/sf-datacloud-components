/**
 * All dynamic Chart.js functions goes here
 */
 const chartFunctionRegistry = {
         groupedLegendFilter: function (item, chart) {
             // Only show the legend item if it's the first time this label appears
             return chart.datasets.findIndex((ds) => ds.label === item.text) ===item.datasetIndex;
           },
           groupedLegendClick: function (e, legendItem, legend) {
               const chart = legend.chart;
               const clickedLabel = legendItem.text;
               // Find all datasets that share this label and toggle their visibility
               chart.data.datasets.forEach((dataset, index) => {
                 if (dataset.label === clickedLabel) {
                   const isCurrentlyVisible = chart.isDatasetVisible(index);
                   chart.setDatasetVisibility(index, !isCurrentlyVisible);
                 }
               });
               chart.update();
             },
             // GENERIC plugin hook to draw text under stacked bars
               drawStackLabels: function (chart) {
                 const { ctx } = chart;

                 // Read custom plugin options from the JSON config, with safe defaults
                 const pluginOptions = chart.config.options.plugins.stackLabelsPlugin || {};

                 const font = pluginOptions.font || "11px Arial";
                 const color = pluginOptions.color || "#666";
                 const paddingTop = pluginOptions.paddingTop || 6;

                 ctx.save();
                 ctx.textAlign = "center";
                 ctx.textBaseline = "top";
                 ctx.font = font;
                 ctx.fillStyle = color;

                 const drawn = {}; // Keeps track so we only draw one label per stack per X-axis label

                 chart.data.datasets.forEach((dataset, i) => {
                   const meta = chart.getDatasetMeta(i);
                   if (!meta.hidden) {
                     meta.data.forEach((element, index) => {
                       const stack = dataset.stack;
                       const key = `${index}-${stack}`; // Unique key for X-axis index + stack string

                       if (!drawn[key] && stack) {
                         drawn[key] = true;

                         // 1. Try to use the custom 'stackLabel' provided in the JSON dataset
                         // 2. Fallback to the raw 'stack' ID (e.g., replacing "FY_Current" with "FY Current")
                         let labelText = dataset.stackLabel || stack.replace(/_/g, " ");

                         // Calculate Y position (bottom of the chart area + our configured padding)
                         const yPos = chart.chartArea.bottom + paddingTop;

                         ctx.fillText(labelText, element.x, yPos);
                       }
                     });
                   }
                 });
                 ctx.restore();
               }
     }

     // ==========================================
     // 2. THE HYDRATOR UTILITY
     // Recursively swaps string markers with real functions
     // ==========================================
     function hydrateChartConfig (configObject, registry) {
       for (const key in configObject) {
         if (typeof configObject[key] === "object" && configObject[key] !== null) {
           // Recurse deeper into nested objects/arrays
           hydrateChartConfig(configObject[key], registry);
         } else if (typeof configObject[key] === "string" && configObject[key].startsWith("@@FUNC:")) {
           // Extract function name and swap it
           const functionName = configObject[key].split("@@FUNC:")[1];
           if (registry[functionName]) {
             configObject[key] = registry[functionName];
           } else {
             console.warn(`Chart.js Hydration Warning: Function '${functionName}' not found in registry.`);
           }
         }
       }
       return configObject;
     }

//Export the function function registry and chart hydrate

export {
    chartFunctionRegistry
    ,hydrateChartConfig
}