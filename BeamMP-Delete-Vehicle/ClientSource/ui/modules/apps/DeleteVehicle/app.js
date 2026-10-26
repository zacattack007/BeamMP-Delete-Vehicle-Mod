angular.module('beamng.apps').directive('deleteVehicle', ['$interval', '$timeout', function ($interval, $timeout) {
  return {
    restrict: 'EA', replace: true, scope: {},
    templateUrl: '/ui/modules/apps/DeleteVehicle/app.html',
    link: function (scope) {
      scope.state = {connected: false, allowed: false, players: [], vehicles: [], admins: []};
      scope.connection = 'Connecting…'; scope.tab = 'vehicles'; scope.notice = ''; scope.busy = false;
      var receivedAt = 0, busyTimer;
      function send(action, value) {
        if (['refresh', 'delete', 'locate', 'clear', 'grant', 'remove', 'reset', 'unsubscribe'].indexOf(action) < 0) return;
        var argument = '';
        if (action === 'refresh' && value != null) {
          if (typeof value !== 'number' || !isFinite(value) || value < 0 || value > 2147483647 || Math.floor(value) !== value) return;
          argument = ', ' + value;
        } else if (['delete', 'locate', 'grant', 'remove'].indexOf(action) >= 0) {
          if (typeof value !== 'string' || value.length > 32 || !(action === 'remove' ? /^[1-9][0-9]*$/ : /^t[0-9]+$/).test(value)) return;
          argument = ', "' + value + '"';
        }
        bngApi.engineLua('if extensions.dvLocator then extensions.dvLocator.uiAction("' + action + '"' + argument + ') end');
      }
      scope.canUse = function () { return scope.state.connected && scope.state.allowed && !scope.busy; };
      scope.selectedPlayer = function () {
        return scope.state.players.filter(function (player) { return player.id === scope.state.selectedId; })[0];
      };
      scope.act = function (action, value) {
        if (scope.busy || (action !== 'refresh' && !scope.canUse())) return;
        scope.busy = true; scope.notice = '';
        send(action, value);
        $timeout.cancel(busyTimer);
        busyTimer = $timeout(function () { scope.busy = false; }, 2000);
      };
      scope.dismiss = function () { scope.confirmation = null; };
      scope.setTab = function (tab) { scope.tab = tab; scope.confirmation = null; };
      scope.changePlayer = function (id) { scope.selectedId = id; scope.confirmation = null; scope.act('refresh', id); };
      scope.askDelete = function (vehicle) {
        var player = scope.selectedPlayer();
        if (!scope.canUse() || !player) return;
        scope.confirmation = {action: 'delete', value: vehicle.token, title: 'Delete vehicle ' + vehicle.id + '?',
          detail: vehicle.description + ' — ' + player.name + ' (Player ' + player.id + ')',
          explanation: 'This removes this vehicle from the server.', button: 'Delete this vehicle'};
      };
      scope.askRemove = function (admin) {
        if (!scope.canUse() || !scope.state.owner) return;
        scope.confirmation = {action: 'remove', value: admin.account, title: 'Remove admin access?',
          detail: admin.name + ' · Account ' + admin.account, explanation: 'They will no longer be able to manage vehicles.', button: 'Remove access'};
      };
      scope.askReset = function () {
        if (!scope.canUse() || !scope.state.owner) return;
        scope.confirmation = {action: 'reset', title: 'Remove all added admins?', detail: 'The configured owner keeps access.',
          explanation: 'Every saved admin permission will be removed.', button: 'Reset permissions'};
      };
      scope.confirm = function () {
        var choice = scope.confirmation;
        if (!choice || !scope.canUse()) return;
        scope.confirmation = null; scope.act(choice.action, choice.value);
      };
      scope.$on('DVAppState', function (_, data) {
        scope.$evalAsync(function () {
          data = data || {};
          scope.state = {
            connected: data.connected === true, allowed: data.allowed === true, owner: data.owner === true,
            configured: data.configured === true, selectedId: data.selectedId,
            players: Array.isArray(data.players) ? data.players : [], vehicles: Array.isArray(data.vehicles) ? data.vehicles : [],
            admins: Array.isArray(data.admins) ? data.admins : [], ownerName: data.ownerName || '', permissionsError: data.permissionsError || ''
          };
          scope.selectedId = data.selectedId;
          receivedAt = Date.now(); scope.busy = false;
          scope.connection = !scope.state.connected ? 'Join a BeamMP server' : (!scope.state.allowed ? 'Access restricted' : (scope.state.owner ? 'Owner access' : 'Admin access'));
          if (!scope.state.owner) scope.tab = 'vehicles';
          var choice = scope.confirmation;
          if (choice) {
            var valid = scope.state.connected && scope.state.allowed;
            if (choice.action === 'delete') valid = valid && scope.state.vehicles.some(function (v) { return v.token === choice.value; });
            else valid = valid && scope.state.owner;
            if (!valid) { scope.confirmation = null; scope.notice = 'The selection changed. Choose the target again.'; }
          }
        });
      });
      scope.$on('DVAppNotice', function (_, data) {
        scope.$evalAsync(function () { scope.notice = data && typeof data.text === 'string' ? data.text : ''; });
      });
      var refresh = $interval(function () { send('refresh', scope.selectedId); }, 5000);
      var clock = $interval(function () {
        if (!receivedAt || Date.now() - receivedAt > 12000) {
          scope.state.connected = false; scope.confirmation = null; scope.connection = 'Waiting for server';
        }
      }, 1000);
      var initial = $timeout(function () { send('refresh'); }, 100);
      scope.$on('$destroy', function () {
        $interval.cancel(refresh); $interval.cancel(clock); $timeout.cancel(initial); $timeout.cancel(busyTimer); send('unsubscribe');
      });
    }
  };
}]);
