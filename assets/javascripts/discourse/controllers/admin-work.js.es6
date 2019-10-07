import { default as computed, observes } from 'ember-addons/ember-computed-decorators';

export default Ember.Controller.extend({
  queryParams: ['month', 'year'],

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
  
  @computed
  years() {
    return [
      2019,
      2020
    ]
  }
})