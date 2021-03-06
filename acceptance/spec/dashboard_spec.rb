require 'securerandom'
require 'colors'

describe 'dashboard', type: :feature do
  include Colors

  let(:team_name) { generate_team_name }
  let(:fly_home) { Dir.mktmpdir }

  before(:each) do
    fly_login 'main'
    fly_with_input("set-team -n #{team_name} --no-really-i-dont-want-any-auth", 'y')
    fly_login team_name
    fly('set-pipeline -n -p some-pipeline -c fixtures/states-pipeline.yml')
    fly('unpause-pipeline -p some-pipeline')
  end

  describe 'view toggle' do
    context 'when the view is the default view' do
      it 'switches to compact view' do
        dash_login team_name
        visit dash_route('/beta/dashboard')
        expect(page).to have_content('HIGH-DENSITY')

        click_on 'high-density'
        expect(page).to have_current_path '/beta/dashboard/hd'
      end
    end

    context 'when the view is the compact view' do
      it 'switches to default view' do
        dash_login team_name
        visit dash_route('/beta/dashboard/hd')
        expect(page).to have_content('HIGH-DENSITY')

        click_on 'high-density'
        expect(page).to have_current_path '/beta/dashboard'
      end
    end
  end

  describe 'default view' do
    context 'with multiple teams' do
      let(:other_team_name) { generate_team_name }

      before do
        fly_login 'main'
        fly_with_input("set-team -n #{other_team_name} --no-really-i-dont-want-any-auth", 'y')

        fly_login other_team_name
        fly('set-pipeline -n -p other-pipeline-private -c fixtures/states-pipeline.yml')
        fly('unpause-pipeline -p other-pipeline-private')
        fly('set-pipeline -n -p other-pipeline-public -c fixtures/states-pipeline.yml')
        fly('unpause-pipeline -p other-pipeline-public')
        fly('expose-pipeline -p other-pipeline-public')

        fly_login team_name
      end

      after do
        fly_login 'main'
        fly_with_input("destroy-team -n #{other_team_name}", other_team_name)
      end

      it 'shows all pipelines from the authenticated team and public pipelines from other teams' do
        dash_login team_name
        visit dash_route('/beta/dashboard')
        within '.dashboard-team-group', text: team_name do
          expect(page).to have_content 'some-pipeline'
        end

        within '.dashboard-team-group', text: other_team_name do
          expect(page).to have_content 'other-pipeline-public'
          expect(page).to_not have_content 'other-pipeline-private'
        end
      end

      it 'shows authenticated team first' do
        dash_login team_name

        visit dash_route('/beta/dashboard')

        expect(page).to have_content(team_name)
        expect(page).to have_content(other_team_name)
        expect(page.first('.dashboard-team-name').text).to eq(team_name)
      end
    end

    context 'when pipelines have different states' do
      before do
        fly('destroy-pipeline -n -p some-pipeline')

        fly('set-pipeline -n -p failing-pipeline -c fixtures/states-pipeline.yml')
        fly('unpause-pipeline -p failing-pipeline')
        fly_fail('trigger-job -w -j failing-pipeline/failing')

        fly('set-pipeline -n -p other-failing-pipeline -c fixtures/states-pipeline.yml')
        fly('unpause-pipeline -p other-failing-pipeline')
        fly_fail('trigger-job -w -j other-failing-pipeline/failing')
        fly('trigger-job -j other-failing-pipeline/running')

        fly('set-pipeline -n -p errored-pipeline -c fixtures/states-pipeline.yml')
        fly('unpause-pipeline -p errored-pipeline')
        fly_fail('trigger-job -w -j errored-pipeline/erroring')

        fly('set-pipeline -n -p aborted-pipeline -c fixtures/states-pipeline.yml')
        fly('unpause-pipeline -p aborted-pipeline')
        fly('trigger-job -j aborted-pipeline/running')
        fly('abort-build -j aborted-pipeline/running -b 1')

        fly('set-pipeline -n -p paused-pipeline -c fixtures/states-pipeline.yml')

        fly('set-pipeline -n -p succeeded-pipeline -c fixtures/states-pipeline.yml')
        fly('unpause-pipeline -p succeeded-pipeline')
        fly('trigger-job -w -j succeeded-pipeline/passing')

        fly('set-pipeline -n -p pending-pipeline -c fixtures/states-pipeline.yml')
        fly('unpause-pipeline -p pending-pipeline')

        fly('expose-pipeline -p failing-pipeline')
        fly('expose-pipeline -p other-failing-pipeline')
        fly('expose-pipeline -p errored-pipeline')
        fly('expose-pipeline -p aborted-pipeline')
        fly('expose-pipeline -p paused-pipeline')
        fly('expose-pipeline -p succeeded-pipeline')
        fly('expose-pipeline -p pending-pipeline')
      end

      it 'displays the pipelines in correct sort order' do
        visit_dashboard
        within '.dashboard-team-group', text: team_name do
          expect(page.find_all('.dashboard-pipeline-name').map(&:text)).to eq(
            ['failing-pipeline', 'other-failing-pipeline', 'errored-pipeline', 'aborted-pipeline', 'paused-pipeline', 'succeeded-pipeline', 'pending-pipeline']
          )
        end
      end
    end

    context 'when a pipeline is paused' do
      before do
        fly('pause-pipeline -p some-pipeline')
        visit_dashboard
      end

      it 'is shown in blue' do
        expect(banner_palette).to eq(BLUE)
      end

      it 'is labelled "paused"' do
        within '.dashboard-pipeline', text: 'some-pipeline' do
          expect(page).to have_content('paused')
        end
      end
    end

    context 'when a pipeline is pending' do
      before do
        fly('trigger-job -j some-pipeline/pending')
        visit_dashboard
      end

      it 'is shown in grey' do
        expect(banner_color).to be_greyscale
      end

      it 'is labelled "pending"' do
        within '.dashboard-pipeline', text: 'some-pipeline' do
          expect(page).to have_content('pending', wait: 10)
        end
      end
    end

    context 'when a pipeline has a failed build' do
      before(:each) do
        fly('set-pipeline -n -p some-other-pipeline -c fixtures/states-pipeline.yml')
        fly('unpause-pipeline -p some-other-pipeline')
        fly_fail('trigger-job -w -j some-other-pipeline/failing')
      end

      it 'is shown in red' do
        visit_dashboard
        expect(banner_palette('some-other-pipeline')).to eq(RED)
      end
    end

    context 'when a pipeline has a passed build' do
      before do
        fly('trigger-job -w -j some-pipeline/passing')
      end

      it 'is shown in green' do
        visit_dashboard
        expect(banner_palette).to eq(GREEN)
      end
    end

    context 'when a pipeline has an aborted build' do
      before do
        fly('trigger-job -j some-pipeline/running')
        fly('abort-build -j some-pipeline/running -b 1')
      end

      it 'is shown in brown' do
        visit_dashboard
        expect(page).to have_css('.dashboard-pipeline.dashboard-status-aborted')
        expect(banner_palette).to eq(BROWN)
      end
    end

    context 'when a pipeline has no builds' do
      it 'is shown in grey' do
        visit_dashboard
        expect(banner_color).to be_greyscale
      end
    end

    context 'when a pipeline has an errored build' do
      before do
        fly_fail('trigger-job -w -j some-pipeline/erroring')
      end

      it 'is shown in amber' do
        visit_dashboard
        expect(banner_palette).to eq(AMBER)
      end
    end

    context 'when a pipeline changes its state' do
      it 'updates the dashboard automatically' do
        visit_dashboard
        expect(banner_color).to be_greyscale
        fly('trigger-job -w -j some-pipeline/passing')
        sleep 5
        expect(banner_palette).to eq(GREEN)
      end
    end

    context 'when a pipeline has multiple failed jobs' do
      let(:current_time) { Time.parse('2017-07-05 05:05:05 EDT') }

      before do
        fly('set-pipeline -n -p some-pipeline -c fixtures/states-pipeline.yml -v path="false"')
        fly_fail('trigger-job -w -j some-pipeline/passing_or_failing')
        fly('set-pipeline -n -p some-pipeline -c fixtures/states-pipeline.yml -v path="true"')
        fly('trigger-job -w -j some-pipeline/passing_or_failing')
        fly('set-pipeline -n -p some-pipeline -c fixtures/states-pipeline.yml -v path="false"')
        fly_fail('trigger-job -w -j some-pipeline/passing_or_failing')
        fly_fail('trigger-job -w -j some-pipeline/passing_or_failing')
        fly_fail('trigger-job -w -j some-pipeline/failing')
      end

      it 'displays the time since the earliest failed build' do
        visit_dashboard
        within '.dashboard-pipeline', text: 'some-pipeline' do
          expect(page.text).to match(/some-pipeline [\d]{1,2}s/)
        end
      end
    end

    it 'anchors URL links on team groups' do
      visit_dashboard
      expect(page).to have_css('.dashboard-team-group', id: team_name)
    end

    it 'links to latest build in the preview' do
      fly_fail('trigger-job -w -j some-pipeline/failing')
      visit_dashboard
      expect(page).to have_css("a[href=\"/beta/teams/#{team_name}/pipelines/some-pipeline/jobs/failing/builds/1\"]")
      expect(page.find("a[href=\"/beta/teams/#{team_name}/pipelines/some-pipeline/jobs/failing/builds/1\"]").text).not_to be_nil
    end
  end

  describe 'high density view' do
    context 'when a pipeline is paused' do
      before do
        fly('pause-pipeline -p some-pipeline')
        visit_hd_dashboard
      end

      it 'has a blue banner' do
        expect(banner_palette).to eq(BLUE)
      end

      it 'displays the name with a black background' do
        expect(title_palette).to eq(BLACK)
      end
    end

    context 'when a pipeline is pending' do
      before do
        fly('trigger-job -j some-pipeline/pending')
        visit_hd_dashboard
      end

      it 'has a gray banner' do
        expect(banner_color).to be_greyscale
      end

      it 'displays its name with a black background' do
        expect(title_palette).to eq(BLACK)
      end
    end

    context 'when a pipeline has a failed build' do
      before(:each) do
        fly_fail('trigger-job -w -j some-pipeline/failing')
        visit_hd_dashboard
      end

      it 'has a red banner' do
        expect(banner_palette).to eq(RED)
      end

      it 'displays its name with a red background' do
        expect(title_palette).to eq(RED)
      end
    end

    context 'when a pipeline has a passed build' do
      before do
        fly('trigger-job -w -j some-pipeline/passing')
        visit_hd_dashboard
      end

      it 'has a green banner' do
        expect(banner_palette).to eq(GREEN)
      end

      it 'displays its name in a black background' do
        expect(title_palette).to eq(BLACK)
      end
    end

    context 'when a pipeline has an aborted build' do
      before do
        fly('trigger-job -j some-pipeline/running')
        fly('abort-build -j some-pipeline/running -b 1')
        visit_hd_dashboard
      end

      it 'has a brown banner' do
        expect(page).to have_css('.dashboard-pipeline.dashboard-status-aborted')
        expect(banner_palette).to eq(BROWN)
      end

      it 'displays its name in a brown background' do
        expect(title_palette).to eq(BLACK)
      end
    end

    context 'when a pipeline has no builds' do
      before do
        visit_hd_dashboard
      end

      it 'has a gray banner' do
        expect(banner_color).to be_greyscale
      end

      it 'displays its name in a black background' do
        expect(title_palette).to eq(BLACK)
      end
    end

    context 'when a pipeline has an errored build' do
      before do
        fly_fail('trigger-job -w -j some-pipeline/erroring')
        visit_hd_dashboard
      end

      it 'has an amber banner' do
        expect(banner_palette).to eq(AMBER)
      end

      it 'displays its name in an amber background' do
        expect(title_palette).to eq(AMBER)
      end
    end

    context 'when a pipeline changes its state' do
      it 'updates the dashboard automatically' do
        visit_hd_dashboard
        expect(banner_color).to be_greyscale
        fly('trigger-job -w -j some-pipeline/passing')
        sleep 5
        expect(banner_palette).to eq(GREEN)
      end
    end
  end

  private

  def login
    @login ||= dash_login team_name
  end

  def banner_palette(pipeline = 'some-pipeline')
    background_palette(banner_element(pipeline))
  end

  def banner_color(pipeline = 'some-pipeline')
    background_color(banner_element(pipeline))
  end

  def banner_element(pipeline = 'some-pipeline')
    page.find('.dashboard-pipeline', text: pipeline).find('.dashboard-pipeline-banner')
  end

  def title_palette(pipeline = 'some-pipeline')
    background_palette(title_element(pipeline))
  end

  def title_element(pipeline = 'some-pipeline')
    page.find('.dashboard-pipeline-content', text: pipeline)
  end

  def visit_dashboard
    login
    visit dash_route('/beta/dashboard')
  end

  def visit_hd_dashboard
    login
    visit dash_route('/beta/dashboard/hd')
  end
end
Capybara.current_session.current_window.resize_to(2000, 2000)
