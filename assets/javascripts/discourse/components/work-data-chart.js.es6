import AdminReportStackedChart from 'admin/components/admin-report-stacked-chart';

export default AdminReportStackedChart.extend({
  layoutName: 'admin/templates/components/admin-report-stacked-chart',

  _buildChartConfig(data) {
    const config = this._super(data);
    config['options']['tooltips']['callbacks']['title'] = tooltipItem => {
      return moment(tooltipItem[0].xLabel, "YYYY-MM").format("MMM YYYY");
    }
    config['options']['scales']['xAxes'][0]['time'] = {
      parser: 'YYYY-MM',
      minUnit: "month"
    }
    return config;
  }
});