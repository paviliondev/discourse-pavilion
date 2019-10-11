import { ajax } from 'discourse/lib/ajax';

export default Discourse.Route.extend({
  queryParams:  {
    month: { replace: true, refreshModel: true },
    year: { replace: true, refreshModel: true }
  },
  
  beforeModel(transition) {
    const routeName = this.routeName;
    const queryParams = this.paramsFor(routeName);
    const now = moment();
    let month = queryParams.month;
    let year = queryParams.year;

    if (!month) {
      month = Number(now.format('M'));
    }
    
    if (!year) {
      year = Number(now.format('Y'));
    }
        
    this.setProperties({ month, year });

    this._super(transition);
  },
  
  model(params) {
    const month = Number(params.month || this.get('month'));
    const year = Number(params.year || this.get('year'));
        
    return ajax('/admin/work', {
      data: {
        month,
        year
      }
    }).then(result => {
      if (result.success) {
        this.setProperties({
          month,
          year
        })
      }
      return result;
    });
  },
  
  setupController(controller, model) {
    console.log(model)
    if (model) {
      controller.setProperties({
        currentMonth: model.current_month,
        previousMonth: model.previous_month,
        nextMonth: model.next_month,
        year: this.get('year'),
        month: this.get('month')
      });
    }
  }
});