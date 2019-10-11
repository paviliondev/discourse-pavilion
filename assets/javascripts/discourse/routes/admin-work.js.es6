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
    const month = params.month || this.get('month');
    const year = params.year || this.get('year');
    
    return ajax('/admin/work', {
      data: {
        month,
        year
      }
    });
  },
  
  setupController(controller, model) {
    if (model) {
      controller.setProperties({
        members: model.members,
        year: Number(model.year),
        month: Number(model.month)
      });
    }
  }
});