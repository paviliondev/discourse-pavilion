import discourseComputed, { observes } from "discourse-common/utils/decorators";
import Controller from "@ember/controller";

const colors = {
  angus: 'blue',
  merefield: 'red',
  Eli: 'green',
  fzngagan: 'yellow',
  pacharanero: 'purple'
}

const workPropNames = [
  'billable_total',
  'earnings_target'
];

export default Controller.extend({
  queryParams: ['month', 'year'],
  chartProp: 'total_month',
  workPropNames: workPropNames,
  
  @discourseComputed
  workProps() {
    return workPropNames.filter(p => p.indexOf('target') === -1)
      .map(p => {
        return {
          id: `${p}_month`,
          name: I18n.t(`admin.work.${p}`)
        }
      });
  },

  @observes('month', 'year')
  updateMonth() {
    const month = this.get('month');
    const year = this.get('year');
    this.transitionToRoute({ queryParams: { month, year }});
  },
  
  @discourseComputed
  months() {
    return moment.months().map((name, index) => {
      return {
        id: index + 1,
        name
      }
    });
  },
  
  @discourseComputed('month', 'months')
  monthName(month, months) {
    return months.find(m => m.id === month).name;
  },
  
  @discourseComputed('currentMonth', 'previousMonth', 'nextMonth', 'chartProp')
  chartData(currentMonth, previousMonth, nextMonth, chartProp) {
    if (currentMonth) {
      const allMonths = [currentMonth, previousMonth, nextMonth].filter(m => {
        return m[0] && m[0].month && moment(m[0].month, "YYYY-MM").isAfter('2019-9-01');
      });
      return currentMonth.map(cm => cm.user.username).map(username => {
        return {
          color: colors[username],
          data: allMonths.map(month => {
            const userMonth = month.find(m => m.user.username === username);
            return {
              x: month[0].month,
              y: userMonth ? userMonth[chartProp] : 0
            }
          }),
          label: username
        }
      });
    } else {
      return [];
    }
  },
  
  @discourseComputed('chartData.[]')
  chartModel(data) {
    return Ember.Object.create({ data });
  },
  
  @discourseComputed
  years() {
    return [
      2019,
      2020
    ].map(y => ({id: y, name: y}))
  }
})