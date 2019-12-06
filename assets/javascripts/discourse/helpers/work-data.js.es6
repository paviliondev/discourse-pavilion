import { registerUnbound } from "discourse-common/lib/helpers";
import { iconHTML } from "discourse-common/lib/icon-library";

function workLabel(value, icon) {
  return `<div class="work-label">${iconHTML(icon)}${value}</div>`
}

registerUnbound("work-data", function(topic) {
  const hours = topic.billable_hours || 0;
  const rate = topic.billable_hour_rate || 0;
  const total = hours * rate;
  const actualHours = topic.actual_hours || 0;
  let html = '';
  
  if (hours) {
    html += workLabel(hours, 'clock-o');
  }
  
  if (rate) {
    html += workLabel(rate, 'funnel-dollar');
  }
  
  if (total) {
    html += workLabel(total, 'dollar-sign');
  }
  
  if (actualHours) {
    html += workLabel(actualHours, 'stopwatch');
  }
  
  return new Handlebars.SafeString(`<div class="work-data">${html}</div>`);
});

registerUnbound('renderProp', function(data, prop) {
  return data[`${prop}_month`];
})