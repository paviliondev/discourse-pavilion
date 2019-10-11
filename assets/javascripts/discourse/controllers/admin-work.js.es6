import { default as computed, observes } from 'ember-addons/ember-computed-decorators';

const colors = {
  angus: 'blue',
  merefield: 'red',
  Eli: 'green',
  fzngagan: 'yellow',
  pacharanero: 'purple'
}

const workPropNames = [
  'billable_total',
  'earnings_target',
  //'actual_hours',
  //'actual_hours_target',
];

export default Ember.Controller.extend({
  queryParams: ['month', 'year'],
  chartProp: 'billable_total_month',
  workPropNames: workPropNames,
  
  @computed
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
  
  @computed
  months() {
    return moment.months().map((name, index) => {
      return {
        id: index + 1,
        name
      }
    });
  },
  
  @computed('month', 'months')
  monthName(month, months) {
    return months.find(m => m.id === month).name;
  },
  
  @computed('currentMonth', 'previousMonth', 'nextMonth', 'chartProp')
  chartData(currentMonth, previousMonth, nextMonth, chartProp) {
    if (currentMonth) {
      const allMonths = [currentMonth, previousMonth, nextMonth].filter(m => m[0]);
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
  
  @computed('chartData.[]')
  chartModel(data) {
    return Ember.Object.create({ data });
  },
  
  @computed
  years() {
    return [
      2019,
      2020
    ]
  }
})